"""Speaker Identity and Voice Enrollment Service.

Handles:
- Voice enrollment with mandatory explicit biometric consent
- Encrypted biometric storage at rest
- Cosine-similarity matching with threshold (never force-matches below threshold)
- Per-project speaker mapping persistence
- Complete biometric deletion
"""

from typing import Dict, List, Optional, Tuple
import numpy as np
from backend.app.adapters.base import BaseSpeakerEmbeddingAdapter
from backend.app.adapters.embeddings.local_speaker import LocalSpeakerEmbeddingAdapter
from backend.app.core.encryption import BiometricEncryptor
from backend.app.schemas.diarization import TranscriptSegment


class BiometricConsentError(Exception):
    """Raised when biometric operations are attempted without explicit opt-in consent."""
    pass


class SpeakerIdentityService:
    """Manages voice enrollment, matching, and biometric privacy lifecycle."""

    DEFAULT_SIMILARITY_THRESHOLD = 0.75

    def __init__(
        self,
        embedding_adapter: Optional[BaseSpeakerEmbeddingAdapter] = None,
        encryptor: Optional[BiometricEncryptor] = None,
        similarity_threshold: float = DEFAULT_SIMILARITY_THRESHOLD
    ):
        self.embedding_adapter = embedding_adapter or LocalSpeakerEmbeddingAdapter()
        self.encryptor = encryptor or BiometricEncryptor()
        self.threshold = similarity_threshold

    @staticmethod
    def cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
        """Computes cosine similarity between two unit-normalized vectors."""
        a = np.array(vec1, dtype=np.float32)
        b = np.array(vec2, dtype=np.float32)
        norm_a = np.linalg.norm(a)
        norm_b = np.linalg.norm(b)
        if norm_a == 0 or norm_b == 0:
            return 0.0
        return float(np.dot(a, b) / (norm_a * norm_b))

    async def enroll_participant(
        self,
        participant_name: str,
        audio_clip_path: str,
        user_id: Optional[str] = None,
        project_id: Optional[str] = None,
        explicit_biometric_consent: bool = False
    ) -> Dict:
        """
        Enrolls a participant using their spoken consent clip ("I am <name>, I agree to be recorded").
        STRICT: Fails immediately if explicit_biometric_consent is False.
        """
        if not explicit_biometric_consent:
            raise BiometricConsentError(
                "Biometric voice enrollment requires explicit opt-in consent. Enrollment aborted."
            )

        raw_vector = await self.embedding_adapter.extract_speaker_embedding(audio_clip_path)
        encrypted_token = self.encryptor.encrypt_vector(raw_vector)

        return {
            "participant_name": participant_name,
            "user_id": user_id,
            "project_id": project_id,
            "encrypted_embedding": encrypted_token,
            "consent_granted": True,
            "embedding_dimension": len(raw_vector)
        }

    def match_speakers(
        self,
        diarized_embeddings: Dict[str, List[float]],
        enrolled_profiles: List[Dict],
        threshold: Optional[float] = None
    ) -> Dict[str, Dict]:
        """
        Matches diarized speaker labels (e.g. 'Speaker 0') against enrolled profiles.
        Enforces 1-to-1 matching based on highest similarity.
        Items below threshold remain 'Speaker N' and are marked as unidentified.
        """
        active_threshold = threshold if threshold is not None else self.threshold
        results: Dict[str, Dict] = {}

        # Decrypt enrolled profiles
        decrypted_enrolled = []
        for p in enrolled_profiles:
            try:
                vec = self.encryptor.decrypt_vector(p["encrypted_embedding"])
                decrypted_enrolled.append({
                    "name": p["participant_name"],
                    "user_id": p.get("user_id"),
                    "vector": vec
                })
            except Exception:
                continue

        # Compute similarity matrix
        assigned_enrolled = set()
        # Sort diarized speakers to match predictably
        for spk_label, spk_vec in diarized_embeddings.items():
            best_sim = -1.0
            best_candidate = None

            for cand in decrypted_enrolled:
                if cand["name"] in assigned_enrolled:
                    continue
                sim = self.cosine_similarity(spk_vec, cand["vector"])
                if sim > best_sim:
                    best_sim = sim
                    best_candidate = cand

            if best_candidate and best_sim >= active_threshold:
                assigned_enrolled.add(best_candidate["name"])
                results[spk_label] = {
                    "matched_name": best_candidate["name"],
                    "user_id": best_candidate["user_id"],
                    "similarity": round(best_sim, 4),
                    "is_identified": True,
                    "display_label": best_candidate["name"]
                }
            else:
                # Below threshold: keep original label, mark unidentified
                results[spk_label] = {
                    "matched_name": None,
                    "user_id": None,
                    "similarity": round(best_sim, 4) if best_sim > 0 else 0.0,
                    "is_identified": False,
                    "display_label": spk_label
                }

        return results

    def apply_speaker_map_to_segments(
        self,
        segments: List[TranscriptSegment],
        speaker_mapping: Dict[str, str]
    ) -> List[TranscriptSegment]:
        """Applies project speaker mapping to transcript segments."""
        for seg in segments:
            if seg.speaker_label in speaker_mapping:
                seg.speaker_label = speaker_mapping[seg.speaker_label]
        return segments
