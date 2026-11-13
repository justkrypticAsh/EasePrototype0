"""Project Management, Invites, and Voice Profile REST Endpoints."""

import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Annotated, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.api.deps import (
    get_current_user,
    require_project_membership,
    require_project_owner
)
from backend.app.database import get_db
from backend.app.models.audit import AuditLog
from backend.app.models.extraction import Claim, Decision, Prerequisite
from backend.app.models.meeting import ConsentRecord, Meeting, Participant, Segment
from backend.app.models.memory import Link, MemoryEmbedding
from backend.app.models.project import Project, ProjectMember, SpeakerProfile
from backend.app.models.user import Invite, User
from backend.app.schemas.api import (
    CollaboratorAddRequest,
    ICloudReportFile,
    ICloudSyncResponse,
    InviteCreateRequest,
    InviteResponse,
    ProjectCreateRequest,
    ProjectMemberResponse,
    ProjectResponse
)
from backend.app.services.speaker_id import SpeakerIdentityService

router = APIRouter(tags=["Projects"])


@router.post("/projects", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
async def create_project(
    request: ProjectCreateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    project = Project(
        name=request.name.strip(),
        description=request.description,
        domain=request.domain,
        language_code=request.language_code,
        recording_policy_text=request.recording_policy_text or (
            "All meetings recorded in this project require advance affirmative participant consent."
        )
    )
    db.add(project)
    await db.flush()

    # Add creator as owner with policy acceptance
    membership = ProjectMember(
        project_id=project.id,
        user_id=current_user.id,
        role="owner",
        policy_accepted_at=datetime.now(timezone.utc)
    )
    db.add(membership)
    await db.commit()
    await db.refresh(project)

    return ProjectResponse(
        id=project.id,
        name=project.name,
        description=project.description,
        domain=project.domain,
        language_code=project.language_code,
        recording_policy_text=project.recording_policy_text,
        role="owner",
        created_at=project.created_at
    )


@router.get("/projects", response_model=List[ProjectResponse])
async def list_my_projects(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    stmt = (
        select(Project, ProjectMember.role)
        .join(ProjectMember, Project.id == ProjectMember.project_id)
        .where(ProjectMember.user_id == current_user.id)
        .order_by(Project.created_at.desc())
    )
    res = await db.execute(stmt)
    results = []
    for project, role in res.all():
        results.append(
            ProjectResponse(
                id=project.id,
                name=project.name,
                description=project.description,
                domain=project.domain,
                language_code=project.language_code,
                recording_policy_text=project.recording_policy_text,
                role=role,
                created_at=project.created_at
            )
        )

    # In prototype/demo mode, auto-provision default workspace if empty
    if not results and current_user.email == "demo@ease.ai":
        default_p = Project(
            name="EASE Architecture Space",
            description="In-person discussion capture, speaker diarization & cross-discussion memory.",
            domain="startup",
            language_code="auto"
        )
        db.add(default_p)
        await db.flush()
        mem = ProjectMember(project_id=default_p.id, user_id=current_user.id, role="owner")
        db.add(mem)
        await db.commit()
        await db.refresh(default_p)
        results.append(
            ProjectResponse(
                id=default_p.id,
                name=default_p.name,
                description=default_p.description,
                domain=default_p.domain,
                language_code=default_p.language_code,
                recording_policy_text=default_p.recording_policy_text,
                role="owner",
                created_at=default_p.created_at
            )
        )

    return results


@router.get("/projects/{project_id}", response_model=ProjectResponse)
async def get_project(
    project_id: str,
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    project = await db.get(Project, project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    return ProjectResponse(
        id=project.id,
        name=project.name,
        description=project.description,
        domain=project.domain,
        language_code=project.language_code,
        recording_policy_text=project.recording_policy_text,
        role=membership.role,
        created_at=project.created_at
    )


@router.get("/projects/{project_id}/members", response_model=List[ProjectMemberResponse])
async def list_members(
    project_id: str,
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    stmt = (
        select(User, ProjectMember.role, ProjectMember.joined_at, ProjectMember.apple_id)
        .join(ProjectMember, User.id == ProjectMember.user_id)
        .where(ProjectMember.project_id == project_id)
    )
    res = await db.execute(stmt)
    return [
        ProjectMemberResponse(
            user_id=u.id,
            email=u.email,
            full_name=u.full_name,
            role=role,
            apple_id=apple_id or u.email,
            joined_at=joined_at
        )
        for u, role, joined_at, apple_id in res.all()
    ]


@router.post("/projects/{project_id}/collaborators", response_model=ProjectMemberResponse, status_code=status.HTTP_201_CREATED)
async def add_collaborator_by_apple_id(
    project_id: str,
    request: CollaboratorAddRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """Adds a collaborator via their Apple ID / iCloud address."""
    clean_apple_id = request.apple_id.strip().lower()

    # Find or provision user account
    stmt = select(User).where(User.email == clean_apple_id)
    res = await db.execute(stmt)
    user = res.scalar_one_or_none()

    if not user:
        from backend.app.core.security import hash_password
        user = User(
            email=clean_apple_id,
            hashed_password=hash_password(secrets.token_urlsafe(16)),
            full_name=request.full_name.strip(),
            is_active=True
        )
        db.add(user)
        await db.flush()

    # Check if already a member
    mem_stmt = select(ProjectMember).where(
        ProjectMember.project_id == project_id,
        ProjectMember.user_id == user.id
    )
    existing_mem = (await db.execute(mem_stmt)).scalar_one_or_none()
    if existing_mem:
        existing_mem.role = request.role
        existing_mem.apple_id = clean_apple_id
        await db.commit()
        await db.refresh(existing_mem)
        return ProjectMemberResponse(
            user_id=user.id,
            email=user.email,
            full_name=user.full_name,
            role=existing_mem.role,
            apple_id=clean_apple_id,
            joined_at=existing_mem.joined_at
        )

    new_member = ProjectMember(
        project_id=project_id,
        user_id=user.id,
        apple_id=clean_apple_id,
        role=request.role,
        policy_accepted_at=datetime.now(timezone.utc)
    )
    db.add(new_member)
    await db.flush()

    # Write AuditLog
    import json
    audit = AuditLog(
        project_id=project_id,
        entity_type="project_member",
        entity_id=new_member.id,
        actor_user_id=current_user.id,
        action="add_collaborator_apple_id",
        new_state_json=json.dumps({"apple_id": clean_apple_id, "role": request.role, "name": request.full_name}),
        reason="Added collaborator via Apple ID"
    )
    db.add(audit)

    await db.commit()
    await db.refresh(new_member)

    return ProjectMemberResponse(
        user_id=user.id,
        email=user.email,
        full_name=user.full_name,
        role=new_member.role,
        apple_id=clean_apple_id,
        joined_at=new_member.joined_at
    )


@router.get("/projects/{project_id}/icloud/reports", response_model=ICloudSyncResponse)
async def get_icloud_shared_reports(
    project_id: str,
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """Generates Markdown and formatted executive summary reports for sync with iCloud Drive."""
    project = await db.get(Project, project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    stmt = (
        select(Meeting)
        .where(Meeting.project_id == project_id)
        .order_by(Meeting.created_at.desc())
    )
    meetings = (await db.execute(stmt)).scalars().all()

    report_files = []
    clean_proj_name = "".join(c for c in project.name if c.isalnum() or c in (" ", "-", "_")).strip()
    safe_folder_name = clean_proj_name or "EASE_Project"

    for m in meetings:
        dec_stmt = select(Decision).where(Decision.meeting_id == m.id)
        decisions = (await db.execute(dec_stmt)).scalars().all()

        claim_stmt = select(Claim).where(Claim.meeting_id == m.id)
        claims = (await db.execute(claim_stmt)).scalars().all()

        prereq_stmt = select(Prerequisite).where(Prerequisite.meeting_id == m.id)
        prereqs = (await db.execute(prereq_stmt)).scalars().all()

        date_str = m.created_at.strftime("%Y-%m-%d")
        safe_title = "".join(c for c in m.title if c.isalnum() or c in (" ", "-", "_")).strip()
        filename = f"{date_str}_{safe_title.replace(' ', '_')}_Report.md"

        md_lines = [
            f"# {m.title}",
            f"**Project**: {project.name} ({project.domain.title()} Domain)",
            f"**Date**: {m.created_at.strftime('%B %d, %Y at %H:%M UTC')}",
            f"**Audio Duration**: {int(m.audio_duration_seconds)}s",
            f"**Status**: {m.status.upper()}",
            "",
            "## 📌 Executive Summary",
            m.summary or "Discussion recorded and processed via EASE Intelligence.",
            "",
            "## 🎯 Key Decisions",
        ]
        if decisions:
            for d in decisions:
                decided = f" *(Decided by {d.decided_by})*" if d.decided_by else ""
                md_lines.append(f"- **{d.text}**{decided} `[{d.timestamp_start_ms//1000}s - {d.timestamp_end_ms//1000}s]`")
        else:
            md_lines.append("- *No explicit decisions logged in this session.*")

        md_lines.extend(["", "## ⚡ Key Claims & Promises"])
        if claims:
            for c in claims:
                md_lines.append(f"- `[{c.type.upper()}]` **{c.speaker_label}**: {c.text} `[{c.timestamp_start_ms//1000}s - {c.timestamp_end_ms//1000}s]` (Status: {c.status.upper()})")
        else:
            md_lines.append("- *No claims extracted.*")

        md_lines.extend(["", "## ⛓️ Prerequisites & Task Dependencies"])
        if prereqs:
            for p in prereqs:
                dep_info = f" *(Depends on: {p.depends_on})*" if p.depends_on else ""
                block_info = f" *(Blocked by: {p.blocked_by_user_name})*" if p.blocked_by_user_name else ""
                owner = f" [Owner: {p.owner_mentioned or 'Unassigned'}]"
                md_lines.append(f"- [{p.status.upper()}] **{p.text}**{owner}{dep_info}{block_info}")
        else:
            md_lines.append("- *No action prerequisites noted.*")

        md_lines.extend([
            "",
            "---",
            "*Generated by EASE Intelligence • Syncable to Apple iCloud Drive / Files*"
        ])

        report_files.append(
            ICloudReportFile(
                filename=filename,
                meeting_id=m.id,
                title=m.title,
                content_markdown="\n".join(md_lines),
                summary=m.summary or "",
                decisions_count=len(decisions),
                claims_count=len(claims),
                prerequisites_count=len(prereqs),
                created_at=m.created_at
            )
        )

    return ICloudSyncResponse(
        project_id=project_id,
        project_name=project.name,
        folder_name=safe_folder_name,
        icloud_path=f"iCloud Drive/EASE/{safe_folder_name}/Reports",
        total_reports=len(report_files),
        reports=report_files,
        last_synced_at=datetime.now(timezone.utc)
    )


@router.post("/projects/{project_id}/invites", response_model=InviteResponse)
async def create_invite(
    project_id: str,
    request: InviteCreateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    code = secrets.token_urlsafe(16)
    expires_at = datetime.now(timezone.utc) + timedelta(days=request.expires_in_days)

    invite = Invite(
        project_id=project_id,
        created_by_user_id=current_user.id,
        code=code,
        expires_at=expires_at,
        max_uses=request.max_uses,
        uses_count=0
    )
    db.add(invite)
    await db.commit()
    await db.refresh(invite)

    return InviteResponse(
        code=invite.code,
        project_id=invite.project_id,
        expires_at=invite.expires_at,
        max_uses=invite.max_uses,
        uses_count=invite.uses_count
    )


@router.post("/invites/{code}/accept")
async def accept_invite(
    code: str,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    stmt = select(Invite).where(Invite.code == code, Invite.is_active == True)
    invite = (await db.execute(stmt)).scalar_one_or_none()

    if not invite:
        raise HTTPException(status_code=400, detail="Invite code is invalid")

    invite_expiry = invite.expires_at
    if invite_expiry.tzinfo is None:
        invite_expiry = invite_expiry.replace(tzinfo=timezone.utc)

    if invite_expiry < datetime.now(timezone.utc) or invite.uses_count >= invite.max_uses:
        raise HTTPException(status_code=400, detail="Invite code is invalid or expired")

    # Check if already member
    check_stmt = select(ProjectMember).where(
        ProjectMember.project_id == invite.project_id,
        ProjectMember.user_id == current_user.id
    )
    existing = (await db.execute(check_stmt)).scalar_one_or_none()
    if existing:
        return {"message": "You are already a member of this project", "project_id": invite.project_id}

    # Add member with policy acceptance timestamp
    membership = ProjectMember(
        project_id=invite.project_id,
        user_id=current_user.id,
        role="member",
        policy_accepted_at=datetime.now(timezone.utc)
    )
    invite.uses_count += 1
    if invite.uses_count >= invite.max_uses:
        invite.is_active = False

    db.add(membership)
    await db.commit()
    return {"message": "Successfully joined project", "project_id": invite.project_id}


@router.delete("/projects/{project_id}")
async def delete_project(
    project_id: str,
    owner_membership: Annotated[ProjectMember, Depends(require_project_owner)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """Owner cascades full deletion: meetings, memory, items, links, and profiles."""
    await db.execute(delete(Link).where(Link.project_id == project_id))
    await db.execute(delete(MemoryEmbedding).where(MemoryEmbedding.project_id == project_id))
    await db.execute(delete(Claim).where(Claim.project_id == project_id))
    await db.execute(delete(Prerequisite).where(Prerequisite.project_id == project_id))
    await db.execute(delete(Decision).where(Decision.project_id == project_id))
    await db.execute(delete(Segment).where(Segment.project_id == project_id))
    await db.execute(delete(ConsentRecord).where(ConsentRecord.project_id == project_id))
    await db.execute(delete(Meeting).where(Meeting.project_id == project_id))
    await db.execute(delete(SpeakerProfile).where(SpeakerProfile.project_id == project_id))
    await db.execute(delete(Invite).where(Invite.project_id == project_id))
    await db.execute(delete(AuditLog).where(AuditLog.project_id == project_id))
    await db.execute(delete(ProjectMember).where(ProjectMember.project_id == project_id))
    await db.execute(delete(Project).where(Project.id == project_id))

    await db.commit()
    return {"message": f"Project {project_id} and all derived assets permanently deleted"}
