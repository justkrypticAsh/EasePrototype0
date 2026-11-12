"""Memory Embeddings and Cross-Discussion Links ORM Models."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import Boolean, DateTime, Float, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from backend.app.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Link(Base):
    __tablename__ = "links"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)

    old_item_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    old_item_type: Mapped[str] = mapped_column(String(32), nullable=False)  # claim | decision | prerequisite

    new_item_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    new_item_type: Mapped[str] = mapped_column(String(32), nullable=False)  # claim | decision | prerequisite

    # CONFIRMS | CONTRADICTS | UPDATES | RESOLVES_PREREQUISITE | NEW
    relation: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    short_reason: Mapped[str] = mapped_column(Text, nullable=False)

    similarity: Mapped[float] = mapped_column(Float, nullable=False)
    judge_confidence: Mapped[float] = mapped_column(Float, nullable=False)

    # Low-confidence contradictions are marked needs_review, never asserted as fact
    needs_review: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class MemoryEmbedding(Base):
    __tablename__ = "memory_embeddings"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    item_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    item_type: Mapped[str] = mapped_column(String(32), nullable=False)  # claim | decision | prerequisite

    # Stored as serialized JSON array of floats for database portability
    embedding_json: Mapped[str] = mapped_column(Text, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
