"""Deepgram STT and Diarization Adapter."""

import os
from typing import Optional
import httpx
from backend.app.adapters.base import BaseSTTAdapter
from backend.app.schemas.diarization import DiarizationResult, TranscriptSegment


class DeepgramAdapter(BaseSTTAdapter):
    """Adapter for Deepgram transcription with diarization."""

    BASE_URL = "https://api.deepgram.com/v1/listen"

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("DEEPGRAM_API_KEY", "")

    async def transcribe(
        self,
        audio_path: str,
        expected_speakers: Optional[int] = None,
        min_speakers: Optional[int] = None,
        max_speakers: Optional[int] = None,
        language_code: Optional[str] = "auto"
    ) -> DiarizationResult:
        if not self.api_key:
            raise ValueError("DEEPGRAM_API_KEY is not configured")

        headers = {
            "Authorization": f"Token {self.api_key}",
            "Content-Type": "audio/wav"
        }

        params = {
            "model": "nova-2",
            "diarize": "true",
            "punctuate": "true",
            "utterances": "true",
        }
        if language_code and language_code != "auto":
            params["language"] = language_code
        else:
            params["detect_language"] = "true"

        async with httpx.AsyncClient(timeout=120.0) as client:
            with open(audio_path, "rb") as f:
                audio_data = f.read()

            response = await client.post(
                self.BASE_URL,
                headers=headers,
                params=params,
                content=audio_data
            )
            response.raise_for_status()
            data = response.json()

            results = data.get("results", {})
            utterances = results.get("utterances", [])
            segments = []
            unique_speakers = set()

            for u in utterances:
                spk = f"Speaker {u.get('speaker', 0)}"
                unique_speakers.add(spk)
                segments.append(
                    TranscriptSegment(
                        speaker_label=spk,
                        start_ms=int(u.get("start", 0) * 1000),
                        end_ms=int(u.get("end", 0) * 1000),
                        text=u.get("transcript", "").strip(),
                        confidence=float(u.get("confidence", 0.90))
                    )
                )

            duration = float(data.get("metadata", {}).get("duration", 0.0))
            detected_lang = results.get("channels", [{}])[0].get("detected_language", language_code)

            return DiarizationResult(
                segments=segments,
                audio_duration_seconds=duration,
                detected_speakers=max(1, len(unique_speakers)),
                provider="deepgram",
                language_code=detected_lang
            )
