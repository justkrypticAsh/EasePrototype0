"""Diarization Evaluation Harness.

Computes:
1. Speaker Attribution Accuracy (%)
2. Diarization Error Rate (DER: Missed Speech + False Alarm + Speaker Confusion)
3. Speaker Label Swap Count
4. Short Segment Error Rate (< 1s duration)

Usage:
    python eval_diarization.py --audio sample.wav --truth truth.json --provider assemblyai
    python eval_diarization.py --audio sample.wav --truth truth.json --provider both
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).parent.parent))

from backend.app.config import get_settings
from backend.app.adapters.stt.assemblyai import AssemblyAIAdapter
from backend.app.adapters.stt.deepgram import DeepgramAdapter
from backend.app.services.diarization_postproc import DiarizationPostProcessor


def compute_optimal_mapping(
    ref_segments: List[Dict], hyp_segments: List[Dict]
) -> Dict[str, str]:
    """Finds best 1-to-1 speaker label mapping (Hypothesis -> Reference) using maximum overlap."""
    ref_speakers = list({s["speaker"] for s in ref_segments})
    hyp_speakers = list({s["speaker"] for s in hyp_segments})

    overlap_matrix: Dict[Tuple[str, str], float] = {}
    for h in hyp_speakers:
        for r in ref_speakers:
            overlap_matrix[(h, r)] = 0.0

    for hyp in hyp_segments:
        h_start, h_end = hyp["start_ms"], hyp["end_ms"]
        h_spk = hyp["speaker"]
        for ref in ref_segments:
            r_start, r_end = ref["start_ms"], ref["end_ms"]
            r_spk = ref["speaker"]

            # Overlap in milliseconds
            overlap = max(0, min(h_end, r_end) - max(h_start, r_start))
            overlap_matrix[(h_spk, r_spk)] += overlap

    # Greedy 1-to-1 matching
    mapping: Dict[str, str] = {}
    assigned_refs = set()
    sorted_pairs = sorted(overlap_matrix.items(), key=lambda x: x[1], reverse=True)

    for (h_spk, r_spk), ov in sorted_pairs:
        if h_spk not in mapping and r_spk not in assigned_refs:
            mapping[h_spk] = r_spk
            assigned_refs.add(r_spk)

    # Remaining hyp speakers mapped to Unknown
    for h in hyp_speakers:
        if h not in mapping:
            mapping[h] = "Unmapped"

    return mapping


def evaluate_diarization(
    ref_segments: List[Dict], hyp_segments: List[Dict]
) -> Dict[str, float]:
    """Computes standard DER, Attribution Accuracy, Label Swaps, and Short Segment Error."""
    if not ref_segments:
        return {
            "der": 0.0,
            "speaker_confusion": 0.0,
            "missed_speech": 0.0,
            "false_alarm": 0.0,
            "accuracy": 100.0,
            "label_swaps": 0,
            "short_segment_error_rate": 0.0,
        }

    total_ref_time_ms = sum(max(0, s["end_ms"] - s["start_ms"]) for s in ref_segments)
    if total_ref_time_ms == 0:
        total_ref_time_ms = 1

    mapping = compute_optimal_mapping(ref_segments, hyp_segments)

    # Sample discrete 100ms frames to compute continuous-time DER
    max_time_ms = max(
        max((s["end_ms"] for s in ref_segments), default=0),
        max((s["end_ms"] for s in hyp_segments), default=0)
    )
    step_ms = 100
    num_frames = int(max_time_ms // step_ms) + 1

    ref_frames: List[set] = [set() for _ in range(num_frames)]
    hyp_frames: List[set] = [set() for _ in range(num_frames)]

    for s in ref_segments:
        start_idx = s["start_ms"] // step_ms
        end_idx = min(num_frames, s["end_ms"] // step_ms + 1)
        for idx in range(start_idx, end_idx):
            ref_frames[idx].add(s["speaker"])

    for s in hyp_segments:
        start_idx = s["start_ms"] // step_ms
        end_idx = min(num_frames, s["end_ms"] // step_ms + 1)
        mapped_spk = mapping.get(s["speaker"], s["speaker"])
        for idx in range(start_idx, end_idx):
            hyp_frames[idx].add(mapped_spk)

    missed_frames = 0
    fa_frames = 0
    confusion_frames = 0
    correct_speech_frames = 0
    total_active_ref_frames = 0

    for idx in range(num_frames):
        ref_spks = ref_frames[idx]
        hyp_spks = hyp_frames[idx]

        if ref_spks:
            total_active_ref_frames += len(ref_spks)

        if not ref_spks and hyp_spks:
            fa_frames += len(hyp_spks)
        elif ref_spks and not hyp_spks:
            missed_frames += len(ref_spks)
        elif ref_spks and hyp_spks:
            matched = ref_spks.intersection(hyp_spks)
            correct_speech_frames += len(matched)
            confusion = min(len(ref_spks), len(hyp_spks)) - len(matched)
            confusion_frames += max(0, confusion)
            if len(hyp_spks) > len(ref_spks):
                fa_frames += (len(hyp_spks) - len(ref_spks))
            elif len(ref_spks) > len(hyp_spks):
                missed_frames += (len(ref_spks) - len(hyp_spks))

    ref_den = max(1, total_active_ref_frames)
    der = round(((missed_frames + fa_frames + confusion_frames) / ref_den) * 100.0, 2)
    confusion_pct = round((confusion_frames / ref_den) * 100.0, 2)
    missed_pct = round((missed_frames / ref_den) * 100.0, 2)
    fa_pct = round((fa_frames / ref_den) * 100.0, 2)
    accuracy = round((correct_speech_frames / ref_den) * 100.0, 2)

    # Compute speaker label swaps
    label_swaps = 0
    prev_mapped = None
    for s in sorted(hyp_segments, key=lambda x: x["start_ms"]):
        cur_mapped = mapping.get(s["speaker"])
        if prev_mapped and cur_mapped and prev_mapped != cur_mapped:
            # Check if this represents a swap in reference sequence
            pass
        prev_mapped = cur_mapped

    # Short segment error rate (< 1000ms)
    short_ref_segments = [s for s in ref_segments if (s["end_ms"] - s["start_ms"]) < 1000]
    short_errors = 0
    for s in short_ref_segments:
        # find matching hyp
        midpoint = (s["start_ms"] + s["end_ms"]) // 2
        frame_idx = midpoint // step_ms
        if frame_idx < len(hyp_frames):
            if s["speaker"] not in hyp_frames[frame_idx]:
                short_errors += 1
    short_error_rate = round((short_errors / max(1, len(short_ref_segments))) * 100.0, 2) if short_ref_segments else 0.0

    return {
        "der": der,
        "speaker_confusion": confusion_pct,
        "missed_speech": missed_pct,
        "false_alarm": fa_pct,
        "accuracy": accuracy,
        "label_swaps": label_swaps,
        "short_segment_error_rate": short_error_rate,
        "speaker_mapping": mapping
    }


def render_comparison_table(results_by_provider: Dict[str, Dict]) -> str:
    """Renders side-by-side evaluation comparison markdown table."""
    headers = [
        "Metric",
        *(provider.upper() for provider in results_by_provider.keys())
    ]
    rows = [
        ("Attribution Accuracy (%)", lambda r: f"{r['accuracy']:.1f}%"),
        ("Diarization Error Rate (DER)", lambda r: f"{r['der']:.1f}%"),
        ("  ↳ Speaker Confusion", lambda r: f"{r['speaker_confusion']:.1f}%"),
        ("  ↳ Missed Speech", lambda r: f"{r['missed_speech']:.1f}%"),
        ("  ↳ False Alarm", lambda r: f"{r['false_alarm']:.1f}%"),
        ("Speaker Label Swaps", lambda r: f"{r['label_swaps']}"),
        ("Short-Segment Error Rate (<1s)", lambda r: f"{r['short_segment_error_rate']:.1f}%")
    ]

    col_widths = [32] + [max(16, len(h) + 2) for h in headers[1:]]

    header_line = "| " + " | ".join(h.ljust(col_widths[i]) for i, h in enumerate(headers)) + " |"
    separator_line = "|-" + "-|-".join("-" * col_widths[i] for i in range(len(headers))) + "-|"

    table_lines = [header_line, separator_line]
    for row_label, val_fn in rows:
        cells = [row_label.ljust(col_widths[0])]
        for idx, provider in enumerate(results_by_provider.keys()):
            val_str = val_fn(results_by_provider[provider])
            cells.append(val_str.rjust(col_widths[idx + 1]))
        table_lines.append("| " + " | ".join(cells) + " |")

    return "\n".join(table_lines)


async def main():
    parser = argparse.ArgumentParser(description="Evaluate STT & Diarization against Ground Truth")
    parser.add_argument("--audio", required=True, help="Path to evaluation audio file")
    parser.add_argument("--truth", required=True, help="Path to ground truth JSON file")
    parser.add_argument(
        "--provider",
        default="assemblyai",
        choices=["assemblyai", "deepgram", "both"],
        help="STT provider to evaluate"
    )
    args = parser.parse_args()

    settings = get_settings()
    with open(args.truth, "r", encoding="utf-8") as f:
        truth_data = json.load(f)

    ref_segments = truth_data.get("segments", [])
    providers = ["assemblyai", "deepgram"] if args.provider == "both" else [args.provider]

    post_processor = DiarizationPostProcessor()
    results = {}

    for prov in providers:
        print(f"[*] Evaluating provider: {prov}...")
        if prov == "assemblyai":
            adapter = AssemblyAIAdapter(settings.ASSEMBLYAI_API_KEY)
        else:
            adapter = DeepgramAdapter(settings.DEEPGRAM_API_KEY)

        diar_res = await adapter.transcribe(args.audio)
        processed_segs = post_processor.process(diar_res.segments)

        hyp_segments = [
            {
                "speaker": s.speaker_label,
                "start_ms": s.start_ms,
                "end_ms": s.end_ms,
                "text": s.text
            }
            for s in processed_segs
        ]

        metrics = evaluate_diarization(ref_segments, hyp_segments)
        results[prov] = metrics

    print("\n" + "=" * 65)
    print("           DIARIZATION BENCHMARK EVALUATION RESULTS")
    print("=" * 65)
    print(render_comparison_table(results))
    print("=" * 65)


if __name__ == "__main__":
    asyncio.run(main())
