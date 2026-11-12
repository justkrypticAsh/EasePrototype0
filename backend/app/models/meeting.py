"""Meeting, Participant, Segment, and ConsentRecord ORM Models."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import Boolean, DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from backend.app.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Meeting(Base):
    __tablename__ = "meetings"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    created_by_user_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    audio_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    audio_duration_seconds: Mapped[float] = mapped_column(Float, default=0.0)

    # Status: uploaded | transcribing | analyzing | linking | ready | failed
    status: Mapped[str] = mapped_column(String(32), default="uploaded", index=True)
    failure_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    retry_count: Mapped[int] = mapped_column(Integer, default=0)

    # Observability & Cost Tracking
    cost_audio_minutes: Mapped[float] = mapped_column(Float, default=0.0)
    cost_llm_tokens: Mapped[int] = mapped_column(Integer, default=0)

    summary: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)


class Participant(Base):
    __tablename__ = "participants"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    meeting_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    user_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    consented: Mapped[bool] = mapped_column(Boolean, default=True)
    consent_timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class ConsentRecord(Base):
    """Immutable audit record of explicit per-meeting participant consent."""
    __tablename__ = "consent_records"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    meeting_id: Mapped[str] = mapped_column(String(36), unique=True, index=True, nullable=False)
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    participants_json: Mapped[str] = mapped_column(Text, nullable=False)  # JSON list
    confirmed_by_json: Mapped[str] = mapped_column(Text, nullable=False)  # JSON list
    spoken_announcement_played: Mapped[bool] = mapped_column(Boolean, default=False)
    any_declined: Mapped[bool] = mapped_column(Boolean, default=False)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class Segment(Base):
    __tablename__ = "segments"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    meeting_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    speaker_label: Mapped[str] = mapped_column(String(64), nullable=False)
    start_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    end_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    confidence: Mapped[float] = mapped_column(Float, default=1.0)

    # Postproc flags
    is_low_confidence: Mapped[bool] = mapped_column(Boolean, default=False)
    is_overlapping: Mapped[bool] = mapped_column(Boolean, default=False)
    suggested_speaker_label: Mapped[str | None] = mapped_column(String(64), nullable=True)
    reconciliation_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
