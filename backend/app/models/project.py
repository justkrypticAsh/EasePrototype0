"""Project, ProjectMember, and SpeakerProfile ORM Models."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import Boolean, DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from backend.app.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Project(Base):
    __tablename__ = "projects"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    domain: Mapped[str] = mapped_column(String(64), default="general")
    language_code: Mapped[str] = mapped_column(String(16), default="auto")
    recording_policy_text: Mapped[str] = mapped_column(
        Text,
        default="All meetings recorded in this project require advance affirmative participant consent."
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)


class ProjectMember(Base):
    __tablename__ = "project_members"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    user_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    apple_id: Mapped[str | None] = mapped_column(String(255), nullable=True)  # Apple ID / iCloud email
    role: Mapped[str] = mapped_column(String(32), default="member")  # owner | member | reviewer
    policy_accepted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class SpeakerProfile(Base):
    __tablename__ = "speaker_profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    user_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)

    # Biometric voice vector encrypted at rest
    encrypted_embedding: Mapped[str] = mapped_column(Text, nullable=False)
    consent_opt_in: Mapped[bool] = mapped_column(Boolean, default=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
