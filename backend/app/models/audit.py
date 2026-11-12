"""AuditLog and Notification ORM Models."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import Boolean, DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from backend.app.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    entity_type: Mapped[str] = mapped_column(String(64), nullable=False)  # claim | prerequisite | project_policy
    entity_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    actor_user_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    action: Mapped[str] = mapped_column(String(64), nullable=False)  # assign | status_change | resolve | reject

    old_state_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    new_state_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True)


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)

    title: Mapped[str] = mapped_column(String(255), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    # report_ready | contradiction_found | item_assigned | status_changed
    type: Mapped[str] = mapped_column(String(64), nullable=False)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
