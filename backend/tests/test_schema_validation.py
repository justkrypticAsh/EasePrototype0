"""Unit tests for Phase 1 strict schema validation."""

import pytest
from pydantic import ValidationError
from backend.app.schemas.analysis import (
    MeetingAnalysisReport,
    ClaimItem,
    ClaimType,
    DecisionItem,
    KeyPointItem,
    PrerequisiteItem,
    ItemStatus,
    OpenQuestionItem
)


def test_valid_meeting_analysis_report():
    report = MeetingAnalysisReport(
        summary="Executive summary of the technical scoping meeting.",
        key_points=[
            KeyPointItem(text="Auth flow requires JWT", timestamp_start_ms=100, timestamp_end_ms=500)
        ],
        decisions=[
            DecisionItem(text="Adopt PostgreSQL schema", timestamp_start_ms=600, timestamp_end_ms=1200, decided_by="Speaker 0")
        ],
        claims=[
            ClaimItem(
                text="The system will handle 10,000 requests per minute",
                speaker_label="Speaker 1",
                timestamp_start_ms=1500,
                timestamp_end_ms=2500,
                type=ClaimType.ESTIMATE,
                confidence=0.9
            )
        ],
        prerequisites=[
            PrerequisiteItem(
                text="Setup cloud database",
                depends_on="AWS account provisioning",
                owner_mentioned="DevOps",
                status=ItemStatus.OPEN,
                timestamp_start_ms=3000,
                timestamp_end_ms=3500
            )
        ],
        open_questions=[
            OpenQuestionItem(text="Who has access to the root credentials?", timestamp_start_ms=3600, timestamp_end_ms=4000)
        ]
    )
    assert report.summary.startswith("Executive summary")
    assert len(report.claims) == 1
    assert report.claims[0].type == ClaimType.ESTIMATE


def test_invalid_timestamps_rejected():
    with pytest.raises(ValidationError) as exc_info:
        ClaimItem(
            text="Invalid timestamp claim",
            speaker_label="Speaker 0",
            timestamp_start_ms=5000,
            timestamp_end_ms=2000,  # Invalid: end < start
            type=ClaimType.FACT_CLAIM,
            confidence=0.8
        )
    assert "timestamp_end_ms" in str(exc_info.value)


def test_invalid_claim_type_rejected():
    with pytest.raises(ValidationError):
        ClaimItem(
            text="Valid claim text",
            speaker_label="Speaker 0",
            timestamp_start_ms=100,
            timestamp_end_ms=200,
            type="invalid_type",  # Not in ClaimType enum
            confidence=0.9
        )


def test_invalid_status_rejected():
    with pytest.raises(ValidationError):
        PrerequisiteItem(
            text="Task",
            status="pending_approval",  # Not in ItemStatus enum
            timestamp_start_ms=100,
            timestamp_end_ms=200
        )


def test_missing_summary_rejected():
    with pytest.raises(ValidationError):
        MeetingAnalysisReport(
            summary="",  # min_length=10
            key_points=[],
            decisions=[],
            claims=[],
            prerequisites=[],
            open_questions=[]
        )
