"""Unit tests for Speaker Identity, Biometrics, and Matching Thresholds."""

import pytest
from backend.app.core.encryption import BiometricEncryptor
from backend.app.schemas.diarization import TranscriptSegment
from backend.app.services.speaker_id import (
    SpeakerIdentityService,
    BiometricConsentError
)
from backend.app.adapters.base import BaseSpeakerEmbeddingAdapter


class DummySpeakerEmbeddingAdapter(BaseSpeakerEmbeddingAdapter):
    def __init__(self, vector):
        self.vector = vector

    async def extract_speaker_embedding(self, audio_path: str):
        return self.vector


@pytest.mark.asyncio
async def test_enrollment_requires_explicit_consent():
    service = SpeakerIdentityService()
    with pytest.raises(BiometricConsentError):
        await service.enroll_participant(
            participant_name="Rohan",
            audio_clip_path="dummy.wav",
            explicit_biometric_consent=False  # Must fail
        )


def test_encryption_at_rest():
    encryptor = BiometricEncryptor()
    vector = [0.123, -0.456, 0.789, 0.0]
    token = encryptor.encrypt_vector(vector)

    assert isinstance(token, str)
    assert token != str(vector)  # Must be encrypted ciphertext

    decrypted = encryptor.decrypt_vector(token)
    assert len(decrypted) == len(vector)
    for orig, dec in zip(vector, decrypted):
        assert abs(orig - dec) < 1e-5


def test_speaker_matching_above_threshold():
    service = SpeakerIdentityService(similarity_threshold=0.75)
    encryptor = BiometricEncryptor()

    # Enrolled profiles
    profile_ashish = {
        "participant_name": "Ashish",
        "user_id": "usr-1",
        "encrypted_embedding": encryptor.encrypt_vector([1.0, 0.0, 0.0])
    }
    profile_priya = {
        "participant_name": "Priya",
        "user_id": "usr-2",
        "encrypted_embedding": encryptor.encrypt_vector([0.0, 1.0, 0.0])
    }

    # Meeting embeddings: Speaker 0 is close to Ashish (0.95 similarity)
    meeting_embeddings = {
        "Speaker 0": [0.95, 0.05, 0.0],
        "Speaker 1": [0.02, 0.98, 0.0]
    }

    matches = service.match_speakers(
        meeting_embeddings,
        [profile_ashish, profile_priya],
        threshold=0.75
    )

    assert matches["Speaker 0"]["is_identified"] is True
    assert matches["Speaker 0"]["matched_name"] == "Ashish"
    assert matches["Speaker 0"]["display_label"] == "Ashish"

    assert matches["Speaker 1"]["is_identified"] is True
    assert matches["Speaker 1"]["matched_name"] == "Priya"


def test_speaker_matching_below_threshold_never_forced():
    service = SpeakerIdentityService(similarity_threshold=0.80)
    encryptor = BiometricEncryptor()

    profile_ashish = {
        "participant_name": "Ashish",
        "user_id": "usr-1",
        "encrypted_embedding": encryptor.encrypt_vector([1.0, 0.0, 0.0])
    }

    # Low similarity (0.2)
    meeting_embeddings = {
        "Speaker 0": [0.2, 0.8, 0.0]
    }

    matches = service.match_speakers(
        meeting_embeddings,
        [profile_ashish],
        threshold=0.80
    )

    # Must stay as "Speaker 0" and remain unidentified
    assert matches["Speaker 0"]["is_identified"] is False
    assert matches["Speaker 0"]["matched_name"] is None
    assert matches["Speaker 0"]["display_label"] == "Speaker 0"


def test_apply_speaker_map_to_segments():
    service = SpeakerIdentityService()
    segments = [
        TranscriptSegment(speaker_label="Speaker 0", start_ms=0, end_ms=1000, text="Hello", confidence=0.9),
        TranscriptSegment(speaker_label="Speaker 1", start_ms=1000, end_ms=2000, text="Hi", confidence=0.9)
    ]
    mapping = {"Speaker 0": "Ashish", "Speaker 1": "Priya"}

    updated = service.apply_speaker_map_to_segments(segments, mapping)
    assert updated[0].speaker_label == "Ashish"
    assert updated[1].speaker_label == "Priya"
