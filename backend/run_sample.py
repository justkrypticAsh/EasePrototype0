"""CLI Tool to run audio ingestion, diarization, and extraction pipeline on a sample audio file.

Usage:
    python run_sample.py sample.m4a --project-domain consulting --expected-speakers 3
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

# Add project root to sys.path
sys.path.insert(0, str(Path(__file__).parent.parent))

from backend.app.config import get_settings
from backend.app.services.audio_normalizer import AudioNormalizer
from backend.app.services.analysis_engine import AnalysisEngine
from backend.app.adapters.stt.assemblyai import AssemblyAIAdapter
from backend.app.adapters.stt.deepgram import DeepgramAdapter
from backend.app.adapters.llm.gemini import GeminiLLMAdapter
from backend.app.adapters.llm.claude import ClaudeLLMAdapter


def format_readable_summary(report, diarization_result) -> str:
    """Formats report into an executive readable console summary."""
    divider = "=" * 70
    lines = [
        divider,
        "                      EASE DISCUSSION ANALYSIS REPORT",
        divider,
        f"Audio Duration: {diarization_result.audio_duration_seconds:.1f}s | Detected Speakers: {diarization_result.detected_speakers} | Provider: {diarization_result.provider}",
        "",
        "SUMMARY:",
        report.summary,
        "",
        f"KEY POINTS ({len(report.key_points)}):"
    ]
    for kp in report.key_points:
        lines.append(f"  • [{kp.timestamp_start_ms}ms - {kp.timestamp_end_ms}ms] {kp.text}")

    lines.append(f"\nDECISIONS REACHED ({len(report.decisions)}):")
    for d in report.decisions:
        decider = f" (by {d.decided_by})" if d.decided_by else ""
        lines.append(f"  ✓ [{d.timestamp_start_ms}ms - {d.timestamp_end_ms}ms] {d.text}{decider}")

    lines.append(f"\nCLAIMS & COMMITMENTS ({len(report.claims)}):")
    for c in report.claims:
        lines.append(
            f"  [{c.type.upper()}] [{c.timestamp_start_ms}ms - {c.timestamp_end_ms}ms] {c.speaker_label} (conf: {c.confidence:.2f}):\n"
            f"      \"{c.text}\""
        )

    lines.append(f"\nPREREQUISITES & DEPENDENCIES ({len(report.prerequisites)}):")
    for p in report.prerequisites:
        dep = f" -> Depends on: {p.depends_on}" if p.depends_on else ""
        owner = f" [Owner: {p.owner_mentioned}]" if p.owner_mentioned else ""
        lines.append(f"  ⏳ [{p.timestamp_start_ms}ms - {p.timestamp_end_ms}ms] [{p.status.upper()}]{owner} {p.text}{dep}")

    lines.append(f"\nOPEN QUESTIONS ({len(report.open_questions)}):")
    for q in report.open_questions:
        lines.append(f"  ? [{q.timestamp_start_ms}ms - {q.timestamp_end_ms}ms] {q.text}")

    lines.append(divider)
    return "\n".join(lines)


async def main():
    parser = argparse.ArgumentParser(description="EASE Discussion Capture & Analysis CLI")
    parser.add_argument("audio", help="Path to audio file (.m4a, .wav, .mp3)")
    parser.add_argument(
        "--project-domain",
        default="consulting",
        choices=["construction", "consulting", "research", "startup", "general"],
        help="Project domain guidance preset"
    )
    parser.add_argument("--expected-speakers", type=int, default=None, help="Hint for expected speaker count")
    parser.add_argument("--language", default="auto", help="Spoken language code (e.g. en, hi, or auto for Hinglish)")
    parser.add_argument("--stt-provider", default=None, choices=["assemblyai", "deepgram"], help="Override STT provider")
    parser.add_argument("--llm-provider", default=None, choices=["gemini", "claude"], help="Override LLM provider")
    parser.add_argument("--output-json", default=None, help="Optional path to write raw JSON output")

    args = parser.parse_args()
    settings = get_settings()

    audio_path = Path(args.audio)
    if not audio_path.exists():
        print(f"Error: audio file '{args.audio}' does not exist.", file=sys.stderr)
        sys.exit(1)

    print(f"[*] Step 1: Ingesting & normalizing audio: {audio_path.name}...")
    normalizer = AudioNormalizer()
    normalized_path, duration = normalizer.normalize(str(audio_path))
    print(f"    Normalized: {normalized_path} (Duration: {duration:.1f}s)")

    print(f"[*] Step 2: Running transcription & diarization...")
    stt_choice = args.stt_provider or settings.STT_PROVIDER
    if stt_choice == "deepgram":
        stt_adapter = DeepgramAdapter(settings.DEEPGRAM_API_KEY)
    else:
        stt_adapter = AssemblyAIAdapter(settings.ASSEMBLYAI_API_KEY)

    diarization_res = await stt_adapter.transcribe(
        audio_path=normalized_path,
        expected_speakers=args.expected_speakers,
        language_code=args.language
    )
    print(f"    Diarized {len(diarization_res.segments)} segments across {diarization_res.detected_speakers} speakers.")

    print(f"[*] Step 3: Analyzing discussion with domain preset '{args.project_domain}'...")
    llm_choice = args.llm_provider or settings.LLM_PROVIDER
    if llm_choice == "claude":
        llm_adapter = ClaudeLLMAdapter(settings.ANTHROPIC_API_KEY)
    else:
        llm_adapter = GeminiLLMAdapter(settings.GEMINI_API_KEY)

    engine = AnalysisEngine(llm_adapter)
    report = await engine.analyze(
        diarization=diarization_res,
        domain=args.project_domain
    )

    print("\n" + format_readable_summary(report, diarization_res))

    report_dict = {
        "metadata": {
            "audio_file": str(audio_path),
            "normalized_file": normalized_path,
            "duration_seconds": duration,
            "domain": args.project_domain,
            "stt_provider": diarization_res.provider,
            "llm_provider": llm_choice,
        },
        "transcript_segments": [s.model_dump() for s in diarization_res.segments],
        "analysis": report.model_dump()
    }

    if args.output_json:
        with open(args.output_json, "w", encoding="utf-8") as out_f:
            json.dump(report_dict, out_f, indent=2)
        print(f"\n[+] Full report saved to JSON: {args.output_json}")
    else:
        print("\n--- JSON OUTPUT ---")
        print(json.dumps(report_dict, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
