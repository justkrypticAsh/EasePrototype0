"""LLM Analysis Engine for EASE Discussions."""

from pathlib import Path
from typing import List, Optional, Set
from pydantic import ValidationError
from backend.app.adapters.base import BaseLLMAdapter
from backend.app.schemas.analysis import MeetingAnalysisReport
from backend.app.schemas.diarization import DiarizationResult, TranscriptSegment


class AnalysisPipelineError(Exception):
    """Raised when LLM extraction fails or returns unrecoverable malformed output."""
    pass


class AnalysisEngine:
    """Orchestrates structured discussion analysis with domain presets, validation & retries."""

    PROMPTS_DIR = Path(__file__).parent.parent / "prompts" / "domain"

    def __init__(self, llm_adapter: BaseLLMAdapter):
        self.llm = llm_adapter

    def load_domain_guidance(self, domain: str) -> str:
        """Loads domain-specific analysis prompt template."""
        domain_clean = domain.lower().strip()
        prompt_file = self.PROMPTS_DIR / domain_clean / "v1.txt"
        if not prompt_file.exists():
            prompt_file = self.PROMPTS_DIR / "general" / "v1.txt"

        if prompt_file.exists():
            return prompt_file.read_text(encoding="utf-8").strip()
        return "Focus on commitments, technical claims, decisions, and action prerequisites."

    def _format_transcript_for_prompt(self, segments: List[TranscriptSegment]) -> str:
        """Formats transcript segments with exact millisecond bounds and speaker labels."""
        lines = []
        for s in segments:
            lines.append(f"[{s.start_ms}ms - {s.end_ms}ms] {s.speaker_label}: {s.text}")
        return "\n".join(lines)

    def _validate_speaker_labels(self, report: MeetingAnalysisReport, valid_speakers: Set[str]) -> List[str]:
        """Ensures the LLM did not hallucinate or modify speaker labels."""
        errors = []
        for idx, claim in enumerate(report.claims):
            if claim.speaker_label not in valid_speakers:
                errors.append(
                    f"Claim[{idx}] has invalid speaker_label '{claim.speaker_label}'. "
                    f"Must be one of: {sorted(list(valid_speakers))}"
                )
        return errors

    async def analyze(
        self,
        diarization: DiarizationResult,
        domain: str = "general",
        custom_instructions: Optional[str] = None
    ) -> MeetingAnalysisReport:
        """
        Executes strict structured analysis over the diarized meeting transcript.
        Retries once on malformed output or invalid speaker labels, then fails gracefully.
        """
        if not diarization.segments:
            raise AnalysisPipelineError("Cannot analyze an empty transcript without segments.")

        valid_speakers = {s.speaker_label for s in diarization.segments}
        domain_guidance = self.load_domain_guidance(domain)
        transcript_text = self._format_transcript_for_prompt(diarization.segments)

        system_prompt = (
            "You are an expert meeting analyst for EASE, an executive project intelligence platform.\n"
            "Your task is to analyze the discussion transcript and extract:\n"
            "1. Comprehensive summary\n"
            "2. Key points (with exact start and end timestamps)\n"
            "3. Concrete decisions (with timestamps and who decided)\n"
            "4. Specific claims (with text, speaker_label, start/end timestamps, type: assumption | promise | fact_claim | estimate, confidence)\n"
            "5. Prerequisites (with depends_on, owner_mentioned, status, start/end timestamps)\n"
            "6. Open questions (with timestamps)\n\n"
            "STRICT RULES:\n"
            f"- Valid speaker labels are ONLY: {sorted(list(valid_speakers))}\n"
            "- You MUST NOT invent, combine, or rename speaker labels under any circumstance.\n"
            "- Every single item MUST carry valid transcript timestamps (timestamp_start_ms, timestamp_end_ms) from the transcript.\n"
            "- All decisions, claims, and prerequisites must be grounded strictly in what was spoken.\n\n"
            f"{domain_guidance}"
        )

        user_prompt = (
            f"Here is the diarized transcript ({diarization.audio_duration_seconds}s total duration):\n\n"
            f"--- TRANSCRIPT START ---\n"
            f"{transcript_text}\n"
            f"--- TRANSCRIPT END ---\n\n"
        )
        if custom_instructions:
            user_prompt += f"Additional project context: {custom_instructions}\n\n"

        user_prompt += (
            "Extract all summary, key points, decisions, claims, prerequisites, and open questions.\n"
            "Output strictly according to the required JSON schema."
        )

        # First attempt
        try:
            report = await self.llm.generate_structured(
                prompt=user_prompt,
                response_schema=MeetingAnalysisReport,
                system_prompt=system_prompt,
                temperature=0.1
            )
            speaker_errors = self._validate_speaker_labels(report, valid_speakers)
            if not speaker_errors:
                return report
        except (ValidationError, Exception) as err:
            speaker_errors = [str(err)]

        # Retry once with validation feedback
        feedback_prompt = (
            f"{user_prompt}\n\n"
            f"ATTENTION: Your previous attempt was rejected due to the following errors:\n"
            + "\n".join(f"- {e}" for e in speaker_errors) + "\n\n"
            f"Please strictly fix these issues. Ensure all speaker labels are strictly within: {sorted(list(valid_speakers))}, "
            "and all timestamps are valid integers matching the transcript."
        )

        try:
            repaired_report = await self.llm.generate_structured(
                prompt=feedback_prompt,
                response_schema=MeetingAnalysisReport,
                system_prompt=system_prompt,
                temperature=0.0
            )
            second_errors = self._validate_speaker_labels(repaired_report, valid_speakers)
            if second_errors:
                raise AnalysisPipelineError(
                    f"LLM analysis failed on retry with speaker validation errors: {'; '.join(second_errors)}"
                )
            return repaired_report
        except Exception as e:
            raise AnalysisPipelineError(f"Analysis extraction failed after retry: {str(e)}") from e
