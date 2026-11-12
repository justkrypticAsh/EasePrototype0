"""Diarization Post-Processing Pipeline.

Implements:
1. Merge consecutive same-speaker segments separated by short gaps (< max_gap_ms).
2. Flag short segments (< 1s) or low confidence as low_confidence_attribution.
3. Detect and mark overlapping speech intervals.
"""

from typing import List
from backend.app.schemas.diarization import TranscriptSegment


class DiarizationPostProcessor:
    """Post-processor for raw STT diarization output."""

    def __init__(
        self,
        max_merge_gap_ms: int = 700,
        min_duration_ms: int = 1000,
        min_confidence: float = 0.85
    ):
        self.max_merge_gap_ms = max_merge_gap_ms
        self.min_duration_ms = min_duration_ms
        self.min_confidence = min_confidence

    def merge_consecutive_segments(
        self, segments: List[TranscriptSegment]
    ) -> List[TranscriptSegment]:
        """Merges adjacent segments from the same speaker if separated by a small gap."""
        if not segments:
            return []

        merged: List[TranscriptSegment] = []
        current = segments[0].model_copy()

        for next_seg in segments[1:]:
            same_speaker = (current.speaker_label == next_seg.speaker_label)
            gap_ms = next_seg.start_ms - current.end_ms

            if same_speaker and 0 <= gap_ms <= self.max_merge_gap_ms:
                # Merge into current
                current.end_ms = max(current.end_ms, next_seg.end_ms)
                current.text = f"{current.text} {next_seg.text}".strip()
                # Weighted or average confidence
                current.confidence = round((current.confidence + next_seg.confidence) / 2.0, 4)
            else:
                merged.append(current)
                current = next_seg.model_copy()

        merged.append(current)
        return merged

    def flag_low_confidence(
        self, segments: List[TranscriptSegment]
    ) -> List[TranscriptSegment]:
        """Flags segments that are shorter than 1s or have confidence below threshold."""
        for seg in segments:
            duration_ms = seg.end_ms - seg.start_ms
            if duration_ms < self.min_duration_ms or seg.confidence < self.min_confidence:
                seg.is_low_confidence = True
        return segments

    def detect_overlapping_speech(
        self, segments: List[TranscriptSegment]
    ) -> List[TranscriptSegment]:
        """Identifies and marks speech intervals where different speakers talk simultaneously."""
        n = len(segments)
        for i in range(n):
            for j in range(i + 1, n):
                seg_a = segments[i]
                seg_b = segments[j]

                # Check if time intervals overlap
                if seg_b.start_ms < seg_a.end_ms and seg_a.start_ms < seg_b.end_ms:
                    if seg_a.speaker_label != seg_b.speaker_label:
                        seg_a.is_overlapping = True
                        seg_b.is_overlapping = True
                        seg_a.is_low_confidence = True
                        seg_b.is_low_confidence = True
                elif seg_b.start_ms >= seg_a.end_ms:
                    # Sorted list optimization
                    break
        return segments

    def process(self, segments: List[TranscriptSegment]) -> List[TranscriptSegment]:
        """Runs the complete post-processing pipeline in order."""
        if not segments:
            return []

        # 1. Sort by start timestamp
        sorted_segs = sorted(segments, key=lambda s: (s.start_ms, s.end_ms))

        # 2. Detect overlaps on raw segments before merging
        overlap_checked = self.detect_overlapping_speech(sorted_segs)

        # 3. Merge consecutive same-speaker segments
        merged = self.merge_consecutive_segments(overlap_checked)

        # 4. Flag low confidence
        flagged = self.flag_low_confidence(merged)

        return flagged
