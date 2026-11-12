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
        select(User, ProjectMember.role, ProjectMember.joined_at)
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
            joined_at=joined_at
        )
        for u, role, joined_at in res.all()
    ]


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
