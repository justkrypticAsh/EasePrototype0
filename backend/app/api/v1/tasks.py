"""Assignment Workflow, Status Updates, and Audit Log REST Endpoints."""

import json
from datetime import datetime, timezone
from typing import Annotated, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.api.deps import (
    get_current_user,
    require_project_membership
)
from backend.app.database import get_db
from backend.app.models.audit import AuditLog, Notification
from backend.app.models.extraction import Claim, Prerequisite
from backend.app.models.project import ProjectMember
from backend.app.models.user import User
from backend.app.schemas.api import (
    AssignmentRequest,
    AuditLogResponse,
    StatusUpdateRequest
)

router = APIRouter(tags=["Tasks & Collaboration"])


@router.patch("/projects/{project_id}/items/{item_type}/{item_id}/assign")
async def assign_item(
    project_id: str,
    item_type: str,
    item_id: str,
    request: AssignmentRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """Assigns a claim or prerequisite to a project member and writes an AuditLog."""
    # Verify assignee is a member of this project
    assignee_membership = (await db.execute(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == request.owner_user_id
        )
    )).scalar_one_or_none()

    if not assignee_membership:
        raise HTTPException(status_code=400, detail="Target assignee is not a member of this project")

    old_owner = None
    if item_type == "claim":
        item = await db.get(Claim, item_id)
    elif item_type == "prerequisite":
        item = await db.get(Prerequisite, item_id)
    else:
        raise HTTPException(status_code=400, detail="Invalid item_type. Must be claim or prerequisite")

    if not item or item.project_id != project_id:
        raise HTTPException(status_code=404, detail="Item not found")

    old_owner = item.owner_user_id
    item.owner_user_id = request.owner_user_id
    item.updated_by = current_user.id
    item.updated_at = datetime.now(timezone.utc)

    # Write AuditLog
    audit = AuditLog(
        project_id=project_id,
        entity_type=item_type,
        entity_id=item_id,
        actor_user_id=current_user.id,
        action="assign",
        old_state_json=json.dumps({"owner_user_id": old_owner}),
        new_state_json=json.dumps({"owner_user_id": request.owner_user_id}),
        reason="Assigned by member"
    )
    db.add(audit)

    # Notify assignee
    db.add(Notification(
        user_id=request.owner_user_id,
        project_id=project_id,
        title="New Task Assigned",
        message=f"{current_user.full_name} assigned you: \"{item.text[:80]}\"",
        type="item_assigned"
    ))

    await db.commit()
    return {"message": "Assignment updated", "item_id": item_id, "owner_user_id": request.owner_user_id}


@router.patch("/projects/{project_id}/items/{item_type}/{item_id}/status")
async def update_item_status(
    project_id: str,
    item_type: str,
    item_id: str,
    request: StatusUpdateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """Updates item status (open | confirmed | rejected | done) with mandatory audit logging."""
    if item_type == "claim":
        item = await db.get(Claim, item_id)
    elif item_type == "prerequisite":
        item = await db.get(Prerequisite, item_id)
    else:
        raise HTTPException(status_code=400, detail="Invalid item_type. Must be claim or prerequisite")

    if not item or item.project_id != project_id:
        raise HTTPException(status_code=404, detail="Item not found")

    # If disagreement, owner decision is final
    if item.owner_user_id and item.owner_user_id != current_user.id and membership.role != "owner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the assigned owner or project owner can change status."
        )

    old_status = item.status
    item.status = request.status
    item.updated_by = current_user.id
    item.updated_at = datetime.now(timezone.utc)

    audit = AuditLog(
        project_id=project_id,
        entity_type=item_type,
        entity_id=item_id,
        actor_user_id=current_user.id,
        action="status_change",
        old_state_json=json.dumps({"status": old_status}),
        new_state_json=json.dumps({"status": request.status}),
        reason=request.reason
    )
    db.add(audit)

    await db.commit()
    return {"message": "Status updated", "item_id": item_id, "status": item.status}


@router.get("/projects/{project_id}/audit", response_model=List[AuditLogResponse])
async def list_audit_logs(
    project_id: str,
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    stmt = (
        select(AuditLog)
        .where(AuditLog.project_id == project_id)
        .order_by(AuditLog.timestamp.desc())
        .limit(100)
    )
    res = await db.execute(stmt)
    logs = res.scalars().all()
    return [
        AuditLogResponse(
            id=log.id,
            project_id=log.project_id,
            entity_type=log.entity_type,
            entity_id=log.entity_id,
            actor_user_id=log.actor_user_id,
            action=log.action,
            old_state=log.old_state_json,
            new_state=log.new_state_json,
            reason=log.reason,
            timestamp=log.timestamp
        )
        for log in logs
    ]
