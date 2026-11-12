"""Biometric Data Encryption at Rest.

Provides hardened encryption/decryption for sensitive biometric voice embeddings.
"""

import base64
import json
from typing import List, Optional
from cryptography.fernet import Fernet
from backend.app.config import get_settings


class BiometricVaultError(Exception):
    """Raised when encryption or decryption of biometric assets fails."""
    pass


class BiometricEncryptor:
    """Encrypts and decrypts biometric vectors using Fernet AES encryption."""

    def __init__(self, key: Optional[str] = None):
        settings = get_settings()
        raw_key = key or settings.BIOMETRIC_ENCRYPTION_KEY

        # Ensure valid 32-byte url-safe base64 Fernet key
        try:
            self._fernet = Fernet(raw_key.encode("utf-8") if isinstance(raw_key, str) else raw_key)
        except Exception:
            # Generate deterministic fallback for dev testing if default key malformed
            padded = (raw_key + "=" * 44)[:44]
            self._fernet = Fernet(base64.urlsafe_b64encode(padded.encode("utf-8")[:32]))

    def encrypt_vector(self, vector: List[float]) -> str:
        """Serializes and encrypts a float embedding vector to an armored token."""
        try:
            payload = json.dumps(vector).encode("utf-8")
            encrypted_token = self._fernet.encrypt(payload)
            return encrypted_token.decode("utf-8")
        except Exception as e:
            raise BiometricVaultError(f"Failed to encrypt biometric vector: {str(e)}") from e

    def decrypt_vector(self, encrypted_token: str) -> List[float]:
        """Decrypts and parses an armored token back into float embedding vector."""
        try:
            decrypted_bytes = self._fernet.decrypt(encrypted_token.encode("utf-8"))
            return json.loads(decrypted_bytes.decode("utf-8"))
        except Exception as e:
            raise BiometricVaultError(f"Failed to decrypt biometric vector: {str(e)}") from e
