"""Asynchronous Pipeline Orchestrator for Meeting Processing."""

import logging
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from backend.app.adapters.base import (
    BaseEmbeddingAdapter,
    BaseLLMAdapter,
    BaseSTTAdapter
)
from backend.app.adapters.embeddings.gemini import GeminiEmbeddingAdapter
from backend.app.adapters.llm.gemini import GeminiLLMAdapter
from backend.app.adapters.stt.assemblyai import AssemblyAIAdapter
from backend.app.adapters.stt.deepgram import DeepgramAdapter
from backend.app.config import get_settings
from backend.app.models.extraction import Claim, Decision, Prerequisite
from backend.app.models.meeting import Meeting, Segment
from backend.app.models.project import Project, SpeakerProfile
from backend.app.services.analysis_engine import AnalysisEngine
from backend.app.services.diarization_postproc import DiarizationPostProcessor
from backend.app.services.memory_engine import MemoryEngine
from backend.app.services.speaker_id import SpeakerIdentityService

logger = logging.getLogger("ease.pipeline")


class MeetingPipelineOrchestrator:
    """Orchestrates end-to-end processing: transcribing -> analyzing -> linking -> ready."""

    def __init__(
        self,
        stt_adapter: Optional[BaseSTTAdapter] = None,
        llm_adapter: Optional[BaseLLMAdapter] = None,
        embedding_adapter: Optional[BaseEmbeddingAdapter] = None
    ):
        settings = get_settings()
        if stt_adapter:
            self.stt = stt_adapter
        elif settings.STT_PROVIDER == "deepgram":
            self.stt = DeepgramAdapter(settings.DEEPGRAM_API_KEY)
        else:
            self.stt = AssemblyAIAdapter(settings.ASSEMBLYAI_API_KEY)

        self.llm = llm_adapter or GeminiLLMAdapter(settings.GEMINI_API_KEY)
        self.embeddings = embedding_adapter or GeminiEmbeddingAdapter(settings.GEMINI_API_KEY)
        self.post_processor = DiarizationPostProcessor()
        self.speaker_service = SpeakerIdentityService()
        self.analysis_engine = AnalysisEngine(self.llm)
        self.memory_engine = MemoryEngine(self.embeddings, self.llm)

    async def process_meeting(
        self,
        meeting_id: str,
        audio_path: str,
        db: AsyncSession
    ) -> None:
        """Executes full meeting pipeline with state tracking and error handling."""
        meeting = await db.get(Meeting, meeting_id)
        if not meeting:
            logger.error(f"Meeting {meeting_id} not found in database")
            return

        project = await db.get(Project, meeting.project_id)
        domain = project.domain if project else "general"

        try:
            # 1. State: transcribing
            meeting.status = "transcribing"
            await db.commit()

            diar_res = await self.stt.transcribe(
                audio_path=audio_path,
                language_code=project.language_code if project else "auto"
            )
            meeting.audio_duration_seconds = diar_res.audio_duration_seconds
            meeting.cost_audio_minutes = round(diar_res.audio_duration_seconds / 60.0, 2)

            # 2. Post-processing
            processed_segments = self.post_processor.process(diar_res.segments)

            # 3. Speaker Identity Matching
            spk_profiles = (await db.execute(
                select(SpeakerProfile).where(SpeakerProfile.project_id == meeting.project_id)
            )).scalars().all()

            if spk_profiles:
                enrolled_dicts = [
                    {
                        "participant_name": p.name,
                        "user_id": p.user_id,
                        "encrypted_embedding": p.encrypted_embedding
                    }
                    for p in spk_profiles
                ]
                # Dummy acoustic embeddings for segment speaker labels
                mock_embs = {
                    s.speaker_label: [0.1] * 192 for s in processed_segments
                }
                matches = self.speaker_service.match_speakers(mock_embs, enrolled_dicts)
                label_map = {k: v["display_label"] for k, v in matches.items() if v["is_identified"]}
                if label_map:
                    processed_segments = self.speaker_service.apply_speaker_map_to_segments(
                        processed_segments, label_map
                    )

            # Store segments
            for s in processed_segments:
                db_seg = Segment(
                    meeting_id=meeting.id,
                    project_id=meeting.project_id,
                    speaker_label=s.speaker_label,
                    start_ms=s.start_ms,
                    end_ms=s.end_ms,
                    text=s.text,
                    confidence=s.confidence,
                    is_low_confidence=s.is_low_confidence,
                    is_overlapping=s.is_overlapping,
                    suggested_speaker_label=s.suggested_speaker_label,
                    reconciliation_reason=s.reconciliation_reason
                )
                db.add(db_seg)
            await db.commit()

            # 4. State: analyzing
            meeting.status = "analyzing"
            await db.commit()

            diar_res.segments = processed_segments
            report = await self.analysis_engine.analyze(diar_res, domain=domain)
            meeting.summary = report.summary
            meeting.cost_llm_tokens = len(report.summary) * 2  # Approx token metric

            # Store Claims
            for c in report.claims:
                db.add(Claim(
                    meeting_id=meeting.id,
                    project_id=meeting.project_id,
                    text=c.text,
                    speaker_label=c.speaker_label,
                    timestamp_start_ms=c.timestamp_start_ms,
                    timestamp_end_ms=c.timestamp_end_ms,
                    type=c.type.value,
                    confidence=c.confidence
                ))

            # Store Decisions
            for d in report.decisions:
                db.add(Decision(
                    meeting_id=meeting.id,
                    project_id=meeting.project_id,
                    text=d.text,
                    timestamp_start_ms=d.timestamp_start_ms,
                    timestamp_end_ms=d.timestamp_end_ms,
                    decided_by=d.decided_by
                ))

            # Store Prerequisites
            for p in report.prerequisites:
                db.add(Prerequisite(
                    meeting_id=meeting.id,
                    project_id=meeting.project_id,
                    text=p.text,
                    depends_on=p.depends_on,
                    owner_mentioned=p.owner_mentioned,
                    status=p.status.value,
                    timestamp_start_ms=p.timestamp_start_ms,
                    timestamp_end_ms=p.timestamp_end_ms
                ))
            await db.commit()

            # 5. State: linking (Cross-discussion Memory)
            meeting.status = "linking"
            await db.commit()

            await self.memory_engine.link_meeting_items(
                project_id=meeting.project_id,
                meeting_id=meeting.id,
                db=db
            )

            # 6. State: ready
            meeting.status = "ready"
            await db.commit()
            logger.info(f"Meeting {meeting.id} processing successfully completed.")

        except Exception as e:
            logger.exception(f"Pipeline failed for meeting {meeting.id}: {str(e)}")
            meeting.status = "failed"
            meeting.failure_reason = str(e)
            meeting.retry_count += 1
            await db.commit()
