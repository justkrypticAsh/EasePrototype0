"""Claude / Anthropic LLM Adapter."""

import json
import os
import re
from typing import Optional, Type, TypeVar
import httpx
from pydantic import BaseModel, ValidationError
from backend.app.adapters.base import BaseLLMAdapter

T = TypeVar("T", bound=BaseModel)


class ClaudeLLMAdapter(BaseLLMAdapter):
    """Adapter for Anthropic Claude models."""

    DEFAULT_MODEL = "claude-3-5-sonnet-20241022"
    BASE_URL = "https://api.anthropic.com/v1/messages"

    def __init__(self, api_key: Optional[str] = None, model: str = DEFAULT_MODEL):
        self.api_key = api_key or os.getenv("ANTHROPIC_API_KEY", "")
        self.model = model

    def _extract_json_block(self, text: str) -> str:
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
            raise ValueError("ANTHROPIC_API_KEY is not configured")

        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json"
        }

        payload = {
            "model": self.model,
            "max_tokens": 4096,
            "temperature": temperature,
            "messages": [{"role": "user", "content": prompt}]
        }
        if system_prompt:
            payload["system"] = system_prompt

        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(self.BASE_URL, headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()
            return data["content"][0]["text"].strip()

    async def generate_structured(
        self,
        prompt: str,
        response_schema: Type[T],
        system_prompt: Optional[str] = None,
        temperature: float = 0.1
    ) -> T:
        schema_json = json.dumps(response_schema.model_json_schema(), indent=2)
        augmented_prompt = (
            f"{prompt}\n\n"
            f"Respond ONLY with a valid JSON object matching this schema:\n"
            f"```json\n{schema_json}\n```\n"
            f"No markdown formatting outside the json block, no preamble."
        )

        raw = await self.generate_text(augmented_prompt, system_prompt, temperature)
        cleaned = self._extract_json_block(raw)
        try:
            return response_schema.model_validate_json(cleaned)
        except ValidationError as err:
            repair_prompt = (
                f"Your JSON output failed validation: {str(err)}\n"
                f"Output was:\n{cleaned}\n\n"
                f"Return ONLY valid JSON matching:\n{schema_json}"
            )
            repaired = await self.generate_text(repair_prompt, system_prompt, 0.0)
            return response_schema.model_validate_json(self._extract_json_block(repaired))
