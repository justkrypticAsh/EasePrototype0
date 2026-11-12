"""Unit tests for Analysis Engine retry logic and domain presets."""

import pytest
from backend.app.schemas.analysis import (
    MeetingAnalysisReport,
    ClaimItem,
    ClaimType
)
from backend.app.services.analysis_engine import AnalysisEngine, AnalysisPipelineError
from backend.tests.conftest import MockLLMAdapter, MockSTTAdapter


@pytest.mark.asyncio
async def test_successful_analysis(mock_stt, mock_llm):
    diarization = await mock_stt.transcribe("dummy.wav")
    engine = AnalysisEngine(mock_llm)

    report = await engine.analyze(diarization, domain="consulting")
    assert report.summary is not None
    assert len(report.claims) > 0
    assert mock_llm.call_count == 1


@pytest.mark.asyncio
async def test_retry_on_hallucinated_speaker_label(mock_stt):
    diarization = await mock_stt.transcribe("dummy.wav")
    # Valid speakers in mock_stt are: Speaker 0, Speaker 1, Speaker 2

    # First response hallucinates "Speaker 99"
    bad_report = MeetingAnalysisReport(
        summary="A summary of the meeting.",
        claims=[
            ClaimItem(
                text="A claim with made-up speaker",
                speaker_label="Speaker 99",  # Invalid
                timestamp_start_ms=1000,
                timestamp_end_ms=2000,
                type=ClaimType.ASSUMPTION,
                confidence=0.8
            )
        ]
    )

    # Second response corrects speaker to "Speaker 1"
    good_report = MeetingAnalysisReport(
        summary="A corrected summary of the meeting.",
        claims=[
            ClaimItem(
                text="A claim with corrected speaker",
                speaker_label="Speaker 1",  # Valid
                timestamp_start_ms=1000,
                timestamp_end_ms=2000,
                type=ClaimType.ASSUMPTION,
                confidence=0.8
            )
        ]
    )

    mock_llm = MockLLMAdapter(response_queue=[bad_report, good_report])
    engine = AnalysisEngine(mock_llm)

    result = await engine.analyze(diarization, domain="startup")
    assert mock_llm.call_count == 2
    assert result.claims[0].speaker_label == "Speaker 1"
    assert "ATTENTION: Your previous attempt was rejected" in mock_llm.recorded_prompts[1]


@pytest.mark.asyncio
async def test_unrecoverable_failure_raises_clear_error(mock_stt):
    diarization = await mock_stt.transcribe("dummy.wav")

    bad_report = MeetingAnalysisReport(
        summary="A summary.",
        claims=[
            ClaimItem(
                text="Hallucinated speaker",
                speaker_label="UnknownSpeaker",
                timestamp_start_ms=1000,
                timestamp_end_ms=2000,
                type=ClaimType.FACT_CLAIM,
                confidence=0.5
            )
        ]
    )

    # Both first and retry attempts return invalid speaker
    mock_llm = MockLLMAdapter(response_queue=[bad_report, bad_report])
    engine = AnalysisEngine(mock_llm)

    with pytest.raises(AnalysisPipelineError) as exc_info:
        await engine.analyze(diarization, domain="construction")
    assert "speaker validation errors" in str(exc_info.value)
    assert mock_llm.call_count == 2


def test_domain_presets_loaded(mock_llm):
    engine = AnalysisEngine(mock_llm)
    for domain in ["construction", "consulting", "research", "startup", "general"]:
        guidance = engine.load_domain_guidance(domain)
        assert len(guidance) > 20
        assert domain.upper() in guidance.upper()
