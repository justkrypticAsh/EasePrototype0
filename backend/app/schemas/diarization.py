"""Diarization and Transcript Schemas."""

from typing import List, Optional
from pydantic import BaseModel, Field


class TranscriptSegment(BaseModel):
    """Normalized transcript segment from STT + Diarization."""
    speaker_label: str = Field(..., description="Diarized speaker label, e.g. 'Speaker 0' or 'Speaker A'")
    start_ms: int = Field(..., ge=0, description="Start time in milliseconds")
    end_ms: int = Field(..., ge=0, description="End time in milliseconds")
    text: str = Field(..., min_length=1, description="Transcribed spoken text")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Word/segment transcription confidence score")

    # Post-processing attributes (Phase 2)
    is_low_confidence: bool = Field(
        default=False,
        description="Flagged true if duration < 1s or confidence is below threshold"
    )
    is_overlapping: bool = Field(
        default=False,
        description="Flagged true if multiple speakers speak at overlapping timestamps"
    )
    suggested_speaker_label: Optional[str] = Field(
        default=None,
        description="Non-destructive LLM reconciliation suggestion (never silently overwrites provider label)"
    )
    reconciliation_reason: Optional[str] = Field(
        default=None,
        description="Explanation for the suggested reconciliation"
    )


class DiarizationResult(BaseModel):
    """Complete STT & diarization transcription payload."""
    segments: List[TranscriptSegment] = Field(default_factory=list)
    audio_duration_seconds: float = Field(..., ge=0.0)
    detected_speakers: int = Field(..., ge=1)
    provider: str = Field(..., description="Provider used (assemblyai or deepgram)")
    language_code: Optional[str] = Field(default="auto")
