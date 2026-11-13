"""Gemini Flash Lite LLM Adapter."""

import json
import os
import re
from typing import Optional, Type, TypeVar
import httpx
from pydantic import BaseModel, ValidationError
from backend.app.adapters.base import BaseLLMAdapter

T = TypeVar("T", bound=BaseModel)


class GeminiLLMAdapter(BaseLLMAdapter):
    """Adapter for Google Gemini models (Gemini Flash default)."""

    DEFAULT_MODEL = "gemini-1.5-flash"
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

    def __init__(self, api_key: Optional[str] = None, model: str = DEFAULT_MODEL):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY", "")
        self.model = model

    def _extract_json_block(self, text: str) -> str:
        """Strip markdown code fence blocks if returned by model."""
        text = text.strip()
        pattern = r"```(?:json)?\s*([\s\S]*?)\s*```"
        match = re.search(pattern, text)
        if match:
            return match.group(1).strip()
        return text

    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.3
    ) -> str:
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY is not configured")

        url = f"{self.BASE_URL}/{self.model}:generateContent?key={self.api_key}"
        contents = []
        if system_prompt:
            contents.append({"role": "user", "parts": [{"text": f"SYSTEM INSTRUCTIONS:\n{system_prompt}"}]})
            contents.append({"role": "model", "parts": [{"text": "Understood. I will strictly adhere to these instructions."}]})
        contents.append({"role": "user", "parts": [{"text": prompt}]})

        payload = {
            "contents": contents,
            "generationConfig": {
                "temperature": temperature,
            }
        }

        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            data = resp.json()
            candidates = data.get("candidates", [])
            if not candidates:
                raise RuntimeError("No candidate response received from Gemini API")
            return candidates[0]["content"]["parts"][0]["text"].strip()

    async def generate_structured(
        self,
        prompt: str,
        response_schema: Type[T],
        system_prompt: Optional[str] = None,
        temperature: float = 0.1
    ) -> T:
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY is not configured")

        schema_json = json.dumps(response_schema.model_json_schema(), indent=2)
        augmented_prompt = (
            f"{prompt}\n\n"
            f"CRITICAL REQUIREMENT: Return ONLY a valid JSON object strictly conforming to this schema:\n"
            f"```json\n{schema_json}\n```\n"
            f"Do not include any conversational preamble, explanations, or extra text."
        )

        raw_response = await self.generate_text(
            prompt=augmented_prompt,
            system_prompt=system_prompt,
            temperature=temperature
        )

        cleaned_json = self._extract_json_block(raw_response)
        try:
            parsed_dict = json.loads(cleaned_json)
            return response_schema.model_validate(parsed_dict)
        except (json.JSONDecodeError, ValidationError) as err:
            # Single-turn repair retry
            repair_prompt = (
                f"Your previous JSON output failed validation with error: {str(err)}\n"
                f"Original output:\n{cleaned_json}\n\n"
                f"Please fix and output ONLY the corrected, valid JSON conforming to the schema:\n"
                f"```json\n{schema_json}\n```"
            )
            repaired_response = await self.generate_text(
                prompt=repair_prompt,
                system_prompt=system_prompt,
                temperature=0.0
            )
            repaired_json = self._extract_json_block(repaired_response)
            parsed_repaired = json.loads(repaired_json)
            return response_schema.model_validate(parsed_repaired)
