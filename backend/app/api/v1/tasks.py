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
    NudgeRequest,
    StatusUpdateRequest,
    TaskDependencyCreateRequest,
    TaskDependencyResponse
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

    if item_type == "prerequisite" and request.status == "done":
        # Unblock dependent tasks and notify
        dep_stmt = select(Prerequisite).where(
            Prerequisite.project_id == project_id,
            Prerequisite.depends_on_task_id == item_id
        )
        dependent_tasks = (await db.execute(dep_stmt)).scalars().all()
        for dep in dependent_tasks:
            db.add(Notification(
                user_id=dep.owner_user_id or current_user.id,
                project_id=project_id,
                title="🟢 Task Unblocked!",
                message=f"Prerequisite \"{item.text[:60]}\" was marked done. You are now unblocked on: \"{dep.text[:60]}\"",
                type="task_unblocked"
            ))

    await db.commit()
    return {"message": "Status updated", "item_id": item_id, "status": item.status}


@router.get("/projects/{project_id}/dependencies", response_model=List[TaskDependencyResponse])
async def list_project_task_dependencies(
    project_id: str,
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """
    Returns all project prerequisites with resolved blocker/dependency states.
    If a prerequisite has depends_on_task_id and the parent task is not 'done',
    is_blocked is True, indicating that this collaborator's work is waiting on another person's action.
    """
    stmt = (
        select(Prerequisite)
        .where(Prerequisite.project_id == project_id)
        .order_by(Prerequisite.created_at.desc())
    )
    prereqs = (await db.execute(stmt)).scalars().all()
    task_map = {p.id: p for p in prereqs}

    users_stmt = (
        select(User, ProjectMember.apple_id)
        .join(ProjectMember, User.id == ProjectMember.user_id)
        .where(ProjectMember.project_id == project_id)
    )
    user_rows = (await db.execute(users_stmt)).all()
    user_names = {u.id: u.full_name for u, _ in user_rows}
    user_apple_ids = {u.id: (apple_id or u.email) for u, apple_id in user_rows}

    results = []
    for p in prereqs:
        is_blocked = False
        blocked_by_name = p.blocked_by_user_name
        blocked_by_apple = p.blocked_by_apple_id
        parent_task_text = p.depends_on

        if p.depends_on_task_id and p.depends_on_task_id in task_map:
            parent = task_map[p.depends_on_task_id]
            parent_task_text = parent.text
            if parent.status != "done":
                is_blocked = True
                if parent.owner_user_id and parent.owner_user_id in user_names:
                    blocked_by_name = user_names[parent.owner_user_id]
                    blocked_by_apple = user_apple_ids.get(parent.owner_user_id)
                elif parent.owner_mentioned:
                    blocked_by_name = parent.owner_mentioned
        elif p.depends_on and p.status != "done":
            is_blocked = True

        owner_name = user_names.get(p.owner_user_id) if p.owner_user_id else p.owner_mentioned
        owner_apple = user_apple_ids.get(p.owner_user_id) if p.owner_user_id else None

        results.append(
            TaskDependencyResponse(
                id=p.id,
                meeting_id=p.meeting_id,
                project_id=p.project_id,
                text=p.text,
                status=p.status,
                owner_name=owner_name,
                owner_apple_id=owner_apple,
                owner_user_id=p.owner_user_id,
                depends_on=parent_task_text,
                depends_on_task_id=p.depends_on_task_id,
                blocked_by_user_name=blocked_by_name,
                blocked_by_apple_id=blocked_by_apple,
                is_blocked=is_blocked and p.status != "done",
                created_at=p.created_at
            )
        )

    return results


@router.post("/projects/{project_id}/tasks/{task_id}/dependency", response_model=TaskDependencyResponse)
async def link_task_dependency(
    project_id: str,
    task_id: str,
    req: TaskDependencyCreateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """Explicitly links a task to depend on another task and flags the blocker collaborator."""
    task = await db.get(Prerequisite, task_id)
    if not task or task.project_id != project_id:
        raise HTTPException(status_code=404, detail="Task not found")

    if req.depends_on_task_id:
        parent = await db.get(Prerequisite, req.depends_on_task_id)
        if not parent or parent.project_id != project_id:
            raise HTTPException(status_code=400, detail="Parent dependency task not found in this project")
        task.depends_on_task_id = parent.id
        task.depends_on = parent.text
        if req.blocked_by_user_name:
            task.blocked_by_user_name = req.blocked_by_user_name
        elif parent.owner_mentioned:
            task.blocked_by_user_name = parent.owner_mentioned
    elif req.depends_on:
        task.depends_on = req.depends_on
        if req.blocked_by_user_name:
            task.blocked_by_user_name = req.blocked_by_user_name

    if req.blocked_by_apple_id:
        task.blocked_by_apple_id = req.blocked_by_apple_id

    task.updated_by = current_user.id
    task.updated_at = datetime.now(timezone.utc)

    # Audit log
    audit = AuditLog(
        project_id=project_id,
        entity_type="task_dependency",
        entity_id=task.id,
        actor_user_id=current_user.id,
        action="link_dependency",
        new_state_json=json.dumps({
            "depends_on": task.depends_on,
            "blocked_by": task.blocked_by_user_name,
            "blocked_by_apple_id": task.blocked_by_apple_id
        }),
        reason="Collaborator dependency linked"
    )
    db.add(audit)
    await db.commit()
    await db.refresh(task)

    return TaskDependencyResponse(
        id=task.id,
        meeting_id=task.meeting_id,
        project_id=task.project_id,
        text=task.text,
        status=task.status,
        owner_name=task.owner_mentioned,
        owner_apple_id=None,
        owner_user_id=task.owner_user_id,
        depends_on=task.depends_on,
        depends_on_task_id=task.depends_on_task_id,
        blocked_by_user_name=task.blocked_by_user_name,
        blocked_by_apple_id=task.blocked_by_apple_id,
        is_blocked=task.status != "done",
        created_at=task.created_at
    )


@router.post("/projects/{project_id}/tasks/{task_id}/nudge")
async def nudge_blocker_collaborator(
    project_id: str,
    task_id: str,
    req: NudgeRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """Sends a priority nudge notification to the collaborator whose action is blocking this task."""
    task = await db.get(Prerequisite, task_id)
    if not task or task.project_id != project_id:
        raise HTTPException(status_code=404, detail="Task not found")

    blocker_name = task.blocked_by_user_name or "Assigned Collaborator"
    msg = req.message or f"Hey {blocker_name}, {current_user.full_name} is waiting on your action to unblock: \"{task.text}\""

    notif = Notification(
        project_id=project_id,
        user_id=current_user.id,
        title="⚠️ Collaborator Action Required (Blocked Task)",
        message=msg,
        type="task_nudge"
    )
    db.add(notif)
    await db.commit()

    return {
        "status": "success",
        "message": f"Nudge sent to {blocker_name}",
        "task_id": task.id
    }


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
