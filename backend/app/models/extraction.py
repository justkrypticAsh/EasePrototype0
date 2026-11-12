"""Claims, Prerequisites, and Decisions ORM Models."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from backend.app.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Claim(Base):
    __tablename__ = "claims"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    meeting_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)

    text: Mapped[str] = mapped_column(Text, nullable=False)
    speaker_label: Mapped[str] = mapped_column(String(64), nullable=False)
    timestamp_start_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    timestamp_end_ms: Mapped[int] = mapped_column(Integer, nullable=False)

    type: Mapped[str] = mapped_column(String(32), nullable=False)  # assumption | promise | fact_claim | estimate
    confidence: Mapped[float] = mapped_column(Float, default=1.0)

    # Workflow & Assignment
    owner_user_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="open", index=True)  # open | confirmed | rejected | done
    updated_by: Mapped[str | None] = mapped_column(String(36), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)


class Prerequisite(Base):
    __tablename__ = "prerequisites"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    meeting_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)

    text: Mapped[str] = mapped_column(Text, nullable=False)
    depends_on: Mapped[str | None] = mapped_column(Text, nullable=True)
    owner_mentioned: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Workflow & Assignment
    owner_user_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="open", index=True)  # open | confirmed | rejected | done

    timestamp_start_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    timestamp_end_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    updated_by: Mapped[str | None] = mapped_column(String(36), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)


class Decision(Base):
    __tablename__ = "decisions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    meeting_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)

    text: Mapped[str] = mapped_column(Text, nullable=False)
    timestamp_start_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    timestamp_end_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    decided_by: Mapped[str | None] = mapped_column(String(255), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
