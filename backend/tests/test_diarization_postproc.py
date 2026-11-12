"""Unit tests for Phase 2 Diarization Post-Processing & Reconciliation."""

import pytest
from backend.app.schemas.diarization import TranscriptSegment
from backend.app.services.diarization_postproc import DiarizationPostProcessor
from backend.app.services.reconciliation import DiarizationReconciler, ReconciliationResult, SuggestedReconciliationItem
from backend.tests.conftest import MockLLMAdapter


def test_merge_consecutive_same_speaker_segments():
    processor = DiarizationPostProcessor(max_merge_gap_ms=700)
    segments = [
        TranscriptSegment(speaker_label="Speaker 0", start_ms=1000, end_ms=2500, text="First part", confidence=0.9),
        # Gap is 300ms (2800 - 2500) -> should merge
        TranscriptSegment(speaker_label="Speaker 0", start_ms=2800, end_ms=4500, text="second part", confidence=0.94),
        # Different speaker -> do not merge
        TranscriptSegment(speaker_label="Speaker 1", start_ms=5000, end_ms=7000, text="other speaker", confidence=0.92)
    ]

    processed = processor.merge_consecutive_segments(segments)
    assert len(processed) == 2
    assert processed[0].speaker_label == "Speaker 0"
    assert processed[0].start_ms == 1000
    assert processed[0].end_ms == 4500
    assert processed[0].text == "First part second part"
    assert processed[1].speaker_label == "Speaker 1"


def test_no_merge_across_large_gaps():
    processor = DiarizationPostProcessor(max_merge_gap_ms=700)
    segments = [
        TranscriptSegment(speaker_label="Speaker 0", start_ms=1000, end_ms=2000, text="Part 1", confidence=0.9),
        # Gap is 1500ms > 700ms -> should NOT merge
        TranscriptSegment(speaker_label="Speaker 0", start_ms=3500, end_ms=4500, text="Part 2", confidence=0.9)
    ]

    processed = processor.merge_consecutive_segments(segments)
    assert len(processed) == 2


def test_flag_short_or_low_confidence():
    processor = DiarizationPostProcessor(min_duration_ms=1000, min_confidence=0.85)
    segments = [
        # Duration 400ms (< 1000ms) -> flag
        TranscriptSegment(speaker_label="Speaker 0", start_ms=1000, end_ms=1400, text="Haan", confidence=0.95),
        # Confidence 0.70 (< 0.85) -> flag
        TranscriptSegment(speaker_label="Speaker 1", start_ms=2000, end_ms=4000, text="Maybe later", confidence=0.70),
        # Normal segment -> no flag
        TranscriptSegment(speaker_label="Speaker 0", start_ms=5000, end_ms=7500, text="Fully agreed on the timeline", confidence=0.98)
    ]

    processed = processor.flag_low_confidence(segments)
    assert processed[0].is_low_confidence is True
    assert processed[1].is_low_confidence is True
    assert processed[2].is_low_confidence is False


def test_detect_overlapping_speech():
    processor = DiarizationPostProcessor()
    segments = [
        TranscriptSegment(speaker_label="Speaker 0", start_ms=1000, end_ms=3000, text="I think we should do this", confidence=0.95),
        # Overlaps from 2000ms to 3000ms
        TranscriptSegment(speaker_label="Speaker 1", start_ms=2000, end_ms=4000, text="No wait let me speak", confidence=0.90),
        # No overlap
        TranscriptSegment(speaker_label="Speaker 0", start_ms=5000, end_ms=6500, text="Okay go ahead", confidence=0.92)
    ]

    processed = processor.detect_overlapping_speech(segments)
    assert processed[0].is_overlapping is True
    assert processed[1].is_overlapping is True
    assert processed[2].is_overlapping is False


@pytest.mark.asyncio
async def test_reconciliation_suggests_without_overwriting():
    segments = [
        TranscriptSegment(
            speaker_label="Speaker 0",
            start_ms=1000,
            end_ms=1400,
            text="Theek hai",
            confidence=0.8,
            is_low_confidence=True
        )
    ]

    suggestion_res = ReconciliationResult(
        suggestions=[
            SuggestedReconciliationItem(
                segment_index=0,
                suggested_speaker_label="Speaker 1",
                reason="Conversational response following question from Speaker 0"
            )
        ]
    )

    mock_llm = MockLLMAdapter(response_queue=[suggestion_res])
    reconciler = DiarizationReconciler(mock_llm)

    reconciled = await reconciler.reconcile_low_confidence_segments(segments)
    # Original label MUST NOT be modified
    assert reconciled[0].speaker_label == "Speaker 0"
    # Suggestion must be stored
    assert reconciled[0].suggested_speaker_label == "Speaker 1"
    assert "Conversational response" in reconciled[0].reconciliation_reason
