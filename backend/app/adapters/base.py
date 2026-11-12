"""Abstract Base Classes for Provider Adapters."""

from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional, Type, TypeVar
from pydantic import BaseModel
from backend.app.schemas.diarization import DiarizationResult

T = TypeVar("T", bound=BaseModel)


class BaseSTTAdapter(ABC):
    """Abstract interface for Speech-to-Text and Speaker Diarization."""

    @abstractmethod
    async def transcribe(
        self,
        audio_path: str,
        expected_speakers: Optional[int] = None,
        min_speakers: Optional[int] = None,
        max_speakers: Optional[int] = None,
        language_code: Optional[str] = "auto"
    ) -> DiarizationResult:
        """Transcribe audio with speaker diarization timestamps."""
        pass


class BaseLLMAdapter(ABC):
    """Abstract interface for Large Language Models."""

    @abstractmethod
    async def generate_structured(
        self,
        prompt: str,
        response_schema: Type[T],
        system_prompt: Optional[str] = None,
        temperature: float = 0.1
    ) -> T:
        """Generate structured output adhering strictly to the response_schema Pydantic model."""
        pass

    @abstractmethod
    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.3
    ) -> str:
        """Generate unstructured text response (e.g. for briefs, Q&A)."""
        pass


class BaseEmbeddingAdapter(ABC):
    """Abstract interface for Text Embeddings."""

    @abstractmethod
    async def embed_texts(self, texts: List[str]) -> List[List[float]]:
        """Generate vector embeddings for a list of text strings."""
        pass

    @abstractmethod
    async def embed_query(self, query: str) -> List[float]:
        """Generate a single vector embedding for a query string."""
        pass


class BaseSpeakerEmbeddingAdapter(ABC):
    """Abstract interface for Speaker Voice Biometric Embeddings."""

    @abstractmethod
    async def extract_speaker_embedding(self, audio_path: str) -> List[float]:
        """Extract a 192-dim or 512-dim d-vector / x-vector for speaker identification."""
        pass
