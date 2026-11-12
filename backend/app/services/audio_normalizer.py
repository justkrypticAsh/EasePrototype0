"""Audio Ingestion and Normalization Service."""

import os
import shutil
import subprocess
from pathlib import Path
from typing import Tuple


class AudioNormalizationError(Exception):
    """Raised when audio conversion or normalization fails."""
    pass


class AudioNormalizer:
    """Normalizes input audio (m4a, mp3, wav, etc.) to 16kHz 16-bit mono WAV."""

    TARGET_SAMPLE_RATE = 16000
    TARGET_CHANNELS = 1
    SUPPORTED_EXTENSIONS = {".m4a", ".wav", ".mp3", ".aac", ".ogg", ".flac"}

    def __init__(self, ffmpeg_path: str = "ffmpeg"):
        self.ffmpeg_path = shutil.which(ffmpeg_path) or ffmpeg_path

    def is_ffmpeg_available(self) -> bool:
        return shutil.which(self.ffmpeg_path) is not None

    def normalize(self, input_path: str, output_path: str = None) -> Tuple[str, float]:
        """
        Normalizes the given audio file to standard 16kHz mono WAV.
        Returns:
            Tuple of (output_file_path, duration_seconds)
        """
        input_file = Path(input_path)
        if not input_file.exists():
            raise AudioNormalizationError(f"Audio file not found: {input_path}")

        if input_file.suffix.lower() not in self.SUPPORTED_EXTENSIONS:
            raise AudioNormalizationError(
                f"Unsupported audio format '{input_file.suffix}'. Supported: {', '.join(self.SUPPORTED_EXTENSIONS)}"
            )

        if not output_path:
            output_path = str(input_file.parent / f"{input_file.stem}_normalized.wav")

        if not self.is_ffmpeg_available():
            # If ffmpeg is not available, check if input is already a wav
            if input_file.suffix.lower() == ".wav":
                if str(input_file.resolve()) != str(Path(output_path).resolve()):
                    shutil.copyfile(input_path, output_path)
                # Estimate rough duration
                duration = max(1.0, os.path.getsize(output_path) / 32000.0)
                return output_path, duration
            raise AudioNormalizationError(
                f"ffmpeg is required to normalize {input_file.suffix} files to 16kHz mono WAV. "
                "Please install ffmpeg (e.g. via 'brew install ffmpeg')."
            )

        cmd = [
            self.ffmpeg_path,
            "-y",
            "-i", str(input_file),
            "-vn",
            "-acodec", "pcm_s16le",
            "-ac", str(self.TARGET_CHANNELS),
            "-ar", str(self.TARGET_SAMPLE_RATE),
            str(output_path)
        ]

        try:
            result = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=True
            )
        except subprocess.CalledProcessError as e:
            raise AudioNormalizationError(f"ffmpeg conversion failed: {e.stderr}") from e
        except Exception as e:
            raise AudioNormalizationError(f"Unexpected error running ffmpeg: {str(e)}") from e

        duration = self.get_duration(output_path)
        return output_path, duration

    def get_duration(self, audio_path: str) -> float:
        """Calculates audio duration in seconds."""
        ffprobe_path = shutil.which("ffprobe")
        if ffprobe_path:
            cmd = [
                ffprobe_path,
                "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                audio_path
            ]
            try:
                out = subprocess.check_output(cmd, text=True).strip()
                return float(out)
            except Exception:
                pass

        # Fallback for 16kHz 16-bit mono PCM wav: 32000 bytes per second
        size_bytes = os.path.getsize(audio_path)
        data_bytes = max(0, size_bytes - 44)
        return round(data_bytes / 32000.0, 2)
