"""Strict Pydantic schemas for LLM Analysis extraction."""

from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator


class ClaimType(str, Enum):
    ASSUMPTION = "assumption"
    PROMISE = "promise"
    FACT_CLAIM = "fact_claim"
    ESTIMATE = "estimate"


class ItemStatus(str, Enum):
    OPEN = "open"
    CONFIRMED = "confirmed"
    REJECTED = "rejected"
    DONE = "done"


class KeyPointItem(BaseModel):
    text: str = Field(..., min_length=2, description="Key discussion point")
    timestamp_start_ms: int = Field(..., ge=0, description="Start timestamp in ms from transcript")
    timestamp_end_ms: int = Field(..., ge=0, description="End timestamp in ms from transcript")

    @field_validator("timestamp_end_ms")
    @classmethod
    def validate_timestamps(cls, v: int, info):
        if "timestamp_start_ms" in info.data and v < info.data["timestamp_start_ms"]:
            raise ValueError(f"timestamp_end_ms ({v}) cannot be less than timestamp_start_ms ({info.data['timestamp_start_ms']})")
        return v


class DecisionItem(BaseModel):
    text: str = Field(..., min_length=2, description="Agreed decision")
    timestamp_start_ms: int = Field(..., ge=0, description="Start timestamp in ms from transcript")
    timestamp_end_ms: int = Field(..., ge=0, description="End timestamp in ms from transcript")
    decided_by: Optional[str] = Field(default=None, description="Speaker label or participant who made/endorsed the decision")

    @field_validator("timestamp_end_ms")
    @classmethod
    def validate_timestamps(cls, v: int, info):
        if "timestamp_start_ms" in info.data and v < info.data["timestamp_start_ms"]:
            raise ValueError(f"timestamp_end_ms ({v}) cannot be less than timestamp_start_ms ({info.data['timestamp_start_ms']})")
        return v


class ClaimItem(BaseModel):
    text: str = Field(..., min_length=2, description="Specific claim made in discussion")
    speaker_label: str = Field(..., description="Exact speaker label who uttered the claim")
    timestamp_start_ms: int = Field(..., ge=0, description="Start timestamp in ms from transcript")
    timestamp_end_ms: int = Field(..., ge=0, description="End timestamp in ms from transcript")
    type: ClaimType = Field(..., description="Classification of the claim")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence of extraction / attribution (0.0 to 1.0)")

    @field_validator("timestamp_end_ms")
    @classmethod
    def validate_timestamps(cls, v: int, info):
        if "timestamp_start_ms" in info.data and v < info.data["timestamp_start_ms"]:
            raise ValueError(f"timestamp_end_ms ({v}) cannot be less than timestamp_start_ms ({info.data['timestamp_start_ms']})")
        return v


class PrerequisiteItem(BaseModel):
    text: str = Field(..., min_length=2, description="Action or dependency item")
    depends_on: Optional[str] = Field(default=None, description="Prior task, event, or deliverable needed")
    owner_mentioned: Optional[str] = Field(default=None, description="Speaker or person assigned in conversation")
    status: ItemStatus = Field(default=ItemStatus.OPEN, description="Initial status of the prerequisite")
    timestamp_start_ms: int = Field(..., ge=0, description="Start timestamp in ms from transcript")
    timestamp_end_ms: int = Field(..., ge=0, description="End timestamp in ms from transcript")

    @field_validator("timestamp_end_ms")
    @classmethod
    def validate_timestamps(cls, v: int, info):
        if "timestamp_start_ms" in info.data and v < info.data["timestamp_start_ms"]:
            raise ValueError(f"timestamp_end_ms ({v}) cannot be less than timestamp_start_ms ({info.data['timestamp_start_ms']})")
        return v


class OpenQuestionItem(BaseModel):
    text: str = Field(..., min_length=2, description="Unresolved or open question from discussion")
    timestamp_start_ms: int = Field(..., ge=0, description="Start timestamp in ms from transcript")
    timestamp_end_ms: int = Field(..., ge=0, description="End timestamp in ms from transcript")

    @field_validator("timestamp_end_ms")
    @classmethod
    def validate_timestamps(cls, v: int, info):
        if "timestamp_start_ms" in info.data and v < info.data["timestamp_start_ms"]:
            raise ValueError(f"timestamp_end_ms ({v}) cannot be less than timestamp_start_ms ({info.data['timestamp_start_ms']})")
        return v


class MeetingAnalysisReport(BaseModel):
    """Complete structured output validated against LLM generation."""
    summary: str = Field(..., min_length=10, description="Comprehensive meeting summary")
    key_points: List[KeyPointItem] = Field(default_factory=list, description="Key discussion takeaways")
    decisions: List[DecisionItem] = Field(default_factory=list, description="Concrete decisions reached")
    claims: List[ClaimItem] = Field(default_factory=list, description="Identified claims with speaker attribution")
    prerequisites: List[PrerequisiteItem] = Field(default_factory=list, description="Actionable prerequisites and dependencies")
    open_questions: List[OpenQuestionItem] = Field(default_factory=list, description="Unresolved questions")
