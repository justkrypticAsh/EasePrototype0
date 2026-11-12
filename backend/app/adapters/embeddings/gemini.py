"""Gemini Text Embeddings Adapter."""

import os
from typing import List, Optional
import httpx
from backend.app.adapters.base import BaseEmbeddingAdapter


class GeminiEmbeddingAdapter(BaseEmbeddingAdapter):
    """Adapter for Google Gemini text embedding models."""

    DEFAULT_MODEL = "text-embedding-004"
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

    def __init__(self, api_key: Optional[str] = None, model: str = DEFAULT_MODEL):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY", "")
        self.model = model

    async def embed_texts(self, texts: List[str]) -> List[List[float]]:
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY is not configured")

        if not texts:
            return []

        url = f"{self.BASE_URL}/{self.model}:batchEmbedContents?key={self.api_key}"
        requests = [
            {
                "model": f"models/{self.model}",
                "content": {"parts": [{"text": text[:2048]}]}
            }
            for text in texts
        ]

        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(url, json={"requests": requests})
            resp.raise_for_status()
            data = resp.json()
            embeddings = [e["values"] for e in data.get("embeddings", [])]
            return embeddings

    async def embed_query(self, query: str) -> List[float]:
        res = await self.embed_texts([query])
        if not res:
            raise RuntimeError("Failed to compute embedding for query")
        return res[0]
