"""Notifications REST Endpoints."""

from typing import Annotated, List
from fastapi import APIRouter, Depends
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.api.deps import get_current_user
from backend.app.database import get_db
from backend.app.models.audit import Notification
from backend.app.models.user import User
from backend.app.schemas.api import NotificationResponse

router = APIRouter(tags=["Notifications"])


@router.get("/notifications", response_model=List[NotificationResponse])
async def list_notifications(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    stmt = (
        select(Notification)
        .where((Notification.user_id == current_user.id) | (Notification.user_id == "project_broadcast"))
        .order_by(Notification.created_at.desc())
        .limit(50)
    )
    res = await db.execute(stmt)
    notifs = res.scalars().all()
    return [
        NotificationResponse(
            id=n.id,
            project_id=n.project_id,
            title=n.title,
            message=n.message,
            type=n.type,
            is_read=n.is_read,
            created_at=n.created_at
        )
        for n in notifs
    ]


@router.patch("/notifications/{notification_id}/read")
async def mark_read(
    notification_id: str,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    stmt = (
        update(Notification)
        .where(Notification.id == notification_id)
        .values(is_read=True)
    )
    await db.execute(stmt)
    await db.commit()
    return {"message": "Notification marked as read"}
