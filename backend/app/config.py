"""Application Configuration for EASE."""

from functools import lru_cache
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    APP_ENV: str = "development"
    APP_NAME: str = "EasePrototype0"
    DEBUG: bool = True
    SECRET_KEY: str = "change-me-to-a-secure-random-secret-key-at-least-32-chars"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Biometric vault AES encryption key (Fernet base64)
    BIOMETRIC_ENCRYPTION_KEY: str = "dGhpcy1pcy1hLXNhbXBsZS1mZXJuZXQta2V5LTEyMzQ1Njc4OTAxMjM0NQ=="

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./ease_prototype.db"

    # Providers
    STT_PROVIDER: str = "assemblyai"      # assemblyai | deepgram
    LLM_PROVIDER: str = "gemini"          # gemini | claude
    EMBEDDING_PROVIDER: str = "gemini"    # gemini

    # API Keys
    ASSEMBLYAI_API_KEY: Optional[str] = None
    DEEPGRAM_API_KEY: Optional[str] = None
    GEMINI_API_KEY: Optional[str] = None
    ANTHROPIC_API_KEY: Optional[str] = None

    # Storage
    AUDIO_STORAGE_PATH: str = "./audio_uploads"
    AUDIO_RETENTION_DAYS: int = 30

    # Rate limits & constraints
    MAX_MEETINGS_PER_DAY: int = 20
    MAX_AUDIO_MINUTES_PER_MEETING: int = 120


@lru_cache()
def get_settings() -> Settings:
    return Settings()
