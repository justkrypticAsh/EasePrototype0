"""AssemblyAI STT and Diarization Adapter."""

import os
from typing import Optional
import httpx
from backend.app.adapters.base import BaseSTTAdapter
from backend.app.schemas.diarization import DiarizationResult, TranscriptSegment


class AssemblyAIAdapter(BaseSTTAdapter):
    """Adapter for AssemblyAI transcription and speaker diarization."""

    BASE_URL = "https://api.assemblyai.com/v2"

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("ASSEMBLYAI_API_KEY", "")

    async def transcribe(
        self,
        audio_path: str,
        expected_speakers: Optional[int] = None,
        min_speakers: Optional[int] = None,
        max_speakers: Optional[int] = None,
        language_code: Optional[str] = "auto"
    ) -> DiarizationResult:
        if not self.api_key:
            raise ValueError("ASSEMBLYAI_API_KEY is not configured")

        headers = {"authorization": self.api_key}

        async with httpx.AsyncClient(timeout=120.0) as client:
            # 1. Upload audio file
            with open(audio_path, "rb") as f:
                upload_resp = await client.post(
                    f"{self.BASE_URL}/upload",
                    headers=headers,
                    content=f.read()
                )
                upload_resp.raise_for_status()
                upload_url = upload_resp.json()["upload_url"]

            # 2. Request transcription with speaker labels
            payload = {
                "audio_url": upload_url,
                "speaker_labels": True,
            }
            if expected_speakers:
                payload["speakers_expected"] = expected_speakers
            if language_code and language_code != "auto":
                payload["language_code"] = language_code
            else:
                payload["language_detection"] = True

            transcribe_resp = await client.post(
                f"{self.BASE_URL}/transcript",
                headers=headers,
                json=payload
            )
            transcribe_resp.raise_for_status()
            transcript_id = transcribe_resp.json()["id"]

            # 3. Poll for completion
            while True:
                poll_resp = await client.get(
                    f"{self.BASE_URL}/transcript/{transcript_id}",
                    headers=headers
                )
                poll_resp.raise_for_status()
                data = poll_resp.json()
                status = data.get("status")
                if status == "completed":
                    break
                elif status == "error":
                    raise RuntimeError(f"AssemblyAI transcription error: {data.get('error')}")
                import asyncio
                await asyncio.sleep(2)

            # 4. Map utterances to TranscriptSegments
            segments = []
            utterances = data.get("utterances", [])
            unique_speakers = set()

            for u in utterances:
                spk = f"Speaker {u.get('speaker', 'Unknown')}"
                unique_speakers.add(spk)
                segments.append(
                    TranscriptSegment(
                        speaker_label=spk,
                        start_ms=int(u.get("start", 0)),
                        end_ms=int(u.get("end", 0)),
                        text=u.get("text", "").strip(),
                        confidence=float(u.get("confidence", 0.95))
                    )
                )

            duration = float(data.get("audio_duration", 0.0))
            return DiarizationResult(
                segments=segments,
                audio_duration_seconds=duration,
                detected_speakers=max(1, len(unique_speakers)),
                provider="assemblyai",
                language_code=data.get("language_code", language_code)
            )
