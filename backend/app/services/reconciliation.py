"""Context-based Diarization Reconciliation Pass.

Uses conversational context to evaluate low-confidence short segments
(e.g., 'haan', 'theek hai', 'yes', 'okay').
STRICT RULE: Only outputs suggestions (suggested_speaker_label, reconciliation_reason);
NEVER silently overwrites or alters the original provider speaker_label.
"""

import json
from typing import List, Optional
from pydantic import BaseModel, Field
from backend.app.adapters.base import BaseLLMAdapter
from backend.app.schemas.diarization import TranscriptSegment


class SuggestedReconciliationItem(BaseModel):
    segment_index: int = Field(..., description="Index of the low-confidence segment")
    suggested_speaker_label: Optional[str] = Field(None, description="Suggested speaker label or None if unsure")
    reason: str = Field(..., description="Contextual justification for the suggestion")


class ReconciliationResult(BaseModel):
    suggestions: List[SuggestedReconciliationItem] = Field(default_factory=list)


class DiarizationReconciler:
    """Non-destructive contextual reconciliation helper."""

    def __init__(self, llm: BaseLLMAdapter):
        self.llm = llm

    async def reconcile_low_confidence_segments(
        self,
        segments: List[TranscriptSegment]
    ) -> List[TranscriptSegment]:
        """
        Scans for segments flagged with is_low_confidence and queries LLM for suggestions.
        Attaches suggestions to segment objects without modifying speaker_label.
        """
        # Find indices of candidate segments
        candidates = [
            (idx, seg) for idx, seg in enumerate(segments)
            if seg.is_low_confidence and len(seg.text.split()) <= 6
        ]

        if not candidates:
            return segments

        # Build context prompt
        context_lines = []
        for idx, s in enumerate(segments):
            marker = " [CANDIDATE FOR RECONCILIATION]" if s.is_low_confidence and len(s.text.split()) <= 6 else ""
            context_lines.append(f"[{idx}] [{s.start_ms}ms-{s.end_ms}ms] {s.speaker_label}: \"{s.text}\"{marker}")

        prompt = (
            "Analyze the following conversation transcript. Several short utterances (marked as CANDIDATE) "
            "may have been misattributed due to cross-talk, short duration, or backchannel affirmations (e.g. 'haan', 'theek hai', 'agree').\n\n"
            "Review each CANDIDATE segment in conversational context. If conversational turn-taking strongly suggests "
            "another speaker uttered it, provide a suggested_speaker_label and reason. Otherwise, leave it as null.\n\n"
            f"Transcript:\n" + "\n".join(context_lines) + "\n\n"
            "Respond ONLY with a JSON object conforming to: { 'suggestions': [ { 'segment_index': int, 'suggested_speaker_label': str | null, 'reason': str } ] }"
        )

        try:
            res: ReconciliationResult = await self.llm.generate_structured(
                prompt=prompt,
                response_schema=ReconciliationResult,
                system_prompt="You are a linguistic diarization specialist. Never invent speaker names outside those present in transcript.",
                temperature=0.0
            )

            # Apply suggestions non-destructively
            for item in res.suggestions:
                if 0 <= item.segment_index < len(segments):
                    seg = segments[item.segment_index]
                    if item.suggested_speaker_label and item.suggested_speaker_label != seg.speaker_label:
                        seg.suggested_speaker_label = item.suggested_speaker_label
                        seg.reconciliation_reason = item.reason
        except Exception:
            # Non-blocking graceful degradation: if reconciliation fails, raw labels remain untouched
            pass

        return segments
