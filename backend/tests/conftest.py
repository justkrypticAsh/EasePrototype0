"""Shared Pytest Fixtures and Mock Adapters."""

import pytest
from typing import List, Optional, Type, TypeVar
from pydantic import BaseModel
from backend.app.adapters.base import (
    BaseSTTAdapter,
    BaseLLMAdapter,
    BaseEmbeddingAdapter,
    BaseSpeakerEmbeddingAdapter
)
from backend.app.schemas.diarization import DiarizationResult, TranscriptSegment
from backend.app.schemas.analysis import (
    MeetingAnalysisReport,
    KeyPointItem,
    DecisionItem,
    ClaimItem,
    ClaimType,
    PrerequisiteItem,
    ItemStatus,
    OpenQuestionItem
)

T = TypeVar("T", bound=BaseModel)


class MockSTTAdapter(BaseSTTAdapter):
    """Mock STT Adapter returning deterministic diarized utterances."""

    def __init__(self, segments: Optional[List[TranscriptSegment]] = None):
        if segments is None:
            self.segments = [
                TranscriptSegment(
                    speaker_label="Speaker 0",
                    start_ms=1000,
                    end_ms=4500,
                    text="We need to finalize the API architecture before starting the frontend.",
                    confidence=0.96
                ),
                TranscriptSegment(
                    speaker_label="Speaker 1",
                    start_ms=5000,
                    end_ms=9200,
                    text="Haan theek hai, I promise to have the OpenAPI spec documented by Friday.",
                    confidence=0.92
                ),
                TranscriptSegment(
                    speaker_label="Speaker 0",
                    start_ms=9500,
                    end_ms=13000,
                    text="Decision is agreed: we will use FastAPI with Pydantic v2 schemas.",
                    confidence=0.98
                ),
                TranscriptSegment(
                    speaker_label="Speaker 2",
                    start_ms=13500,
                    end_ms=17200,
                    text="Our database migration depends on client approval of the security audit.",
                    confidence=0.88
                )
            ]
        else:
            self.segments = segments

    async def transcribe(
        self,
        audio_path: str,
        expected_speakers: Optional[int] = None,
        min_speakers: Optional[int] = None,
        max_speakers: Optional[int] = None,
        language_code: Optional[str] = "auto"
    ) -> DiarizationResult:
        speakers = {s.speaker_label for s in self.segments}
        duration = (self.segments[-1].end_ms / 1000.0) if self.segments else 1.0
        return DiarizationResult(
            segments=self.segments,
            audio_duration_seconds=duration,
            detected_speakers=len(speakers),
            provider="mock_stt",
            language_code=language_code
        )


class MockLLMAdapter(BaseLLMAdapter):
    """Mock LLM Adapter supporting scripted responses and controlled failures."""

    def __init__(self, response_queue: Optional[List[BaseModel]] = None):
        self.response_queue = response_queue or []
        self.call_count = 0
        self.recorded_prompts = []

    async def generate_structured(
        self,
        prompt: str,
        response_schema: Type[T],
        system_prompt: Optional[str] = None,
        temperature: float = 0.1
    ) -> T:
        self.recorded_prompts.append(prompt)
        self.call_count += 1

        if self.response_queue:
            item = self.response_queue.pop(0)
            if isinstance(item, Exception):
                raise item
            return item

        # Default valid structured report
        return MeetingAnalysisReport(
            summary="The team agreed on FastAPI architecture and set deliverables for Friday.",
            key_points=[
                KeyPointItem(
                    text="API architecture must precede frontend development",
                    timestamp_start_ms=1000,
                    timestamp_end_ms=4500
                )
            ],
            decisions=[
                DecisionItem(
                    text="Use FastAPI with Pydantic v2 schemas",
                    timestamp_start_ms=9500,
                    timestamp_end_ms=13000,
                    decided_by="Speaker 0"
                )
            ],
            claims=[
                ClaimItem(
                    text="I promise to have the OpenAPI spec documented by Friday",
                    speaker_label="Speaker 1",
                    timestamp_start_ms=5000,
                    timestamp_end_ms=9200,
                    type=ClaimType.PROMISE,
                    confidence=0.95
                )
            ],
            prerequisites=[
                PrerequisiteItem(
                    text="Database migration requires client approval",
                    depends_on="Client approval of security audit",
                    owner_mentioned="Speaker 2",
                    status=ItemStatus.OPEN,
                    timestamp_start_ms=13500,
                    timestamp_end_ms=17200
                )
            ],
            open_questions=[
                OpenQuestionItem(
                    text="When will the client complete the security audit?",
                    timestamp_start_ms=13500,
                    timestamp_end_ms=17200
                )
            ]
        )

    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.3
    ) -> str:
        return "Generated spoken brief: In our last discussion, the team finalized FastAPI..."


class MockEmbeddingAdapter(BaseEmbeddingAdapter):
    """Deterministic mock embedding adapter."""

    async def embed_texts(self, texts: List[str]) -> List[List[float]]:
        # Generate predictable 768-dim vector based on text hash
        results = []
        for t in texts:
            seed = sum(ord(c) for c in t) % 100
            vec = [float((i + seed) % 10) / 10.0 for i in range(768)]
            # normalize
            norm = sum(x * x for x in vec) ** 0.5
            results.append([x / norm for x in vec])
        return results

    async def embed_query(self, query: str) -> List[float]:
        res = await self.embed_texts([query])
        return res[0]


@pytest.fixture
def mock_stt():
    return MockSTTAdapter()


@pytest.fixture
def mock_llm():
    return MockLLMAdapter()


@pytest.fixture
def mock_embeddings():
    return MockEmbeddingAdapter()
