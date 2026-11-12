"""API Request and Response DTO Schemas."""

from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, EmailStr, Field


# Auth Schemas
class UserSignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    full_name: str = Field(..., min_length=2)


class UserLoginRequest(BaseModel):
    email: EmailStr
    password: str


class AppleLoginRequest(BaseModel):
    apple_sub: str
    email: EmailStr
    full_name: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    email: str
    full_name: str


class UserResponse(BaseModel):
    id: str
    email: str
    full_name: str
    is_active: bool
    created_at: datetime


# Project Schemas
class ProjectCreateRequest(BaseModel):
    name: str = Field(..., min_length=2)
    description: Optional[str] = None
    domain: str = "general"
    language_code: str = "auto"
    recording_policy_text: Optional[str] = None


class ProjectResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    domain: str
    language_code: str
    recording_policy_text: str
    role: Optional[str] = None
    created_at: datetime


class ProjectMemberResponse(BaseModel):
    user_id: str
    email: str
    full_name: str
    role: str
    joined_at: datetime


class InviteCreateRequest(BaseModel):
    max_uses: int = 1
    expires_in_days: int = 7


class InviteResponse(BaseModel):
    code: str
    project_id: str
    expires_at: datetime
    max_uses: int
    uses_count: int


# Meeting & Consent Schemas
class MeetingCreateRequest(BaseModel):
    title: str = Field(..., min_length=2)
    participants: List[str] = Field(..., min_length=1, description="Names of in-person participants")
    spoken_announcement_played: bool = False
    all_consented: bool = True
    declined_participants: List[str] = Field(default_factory=list)


class MeetingStatusResponse(BaseModel):
    id: str
    project_id: str
    title: str
    status: str
    audio_duration_seconds: float
    cost_audio_minutes: float
    cost_llm_tokens: int
    failure_reason: Optional[str] = None
    created_at: datetime


# Task & Collaboration Schemas
class StatusUpdateRequest(BaseModel):
    status: str = Field(..., pattern="^(open|confirmed|rejected|done)$")
    reason: Optional[str] = None


class AssignmentRequest(BaseModel):
    owner_user_id: str


class AuditLogResponse(BaseModel):
    id: str
    project_id: str
    entity_type: str
    entity_id: str
    actor_user_id: str
    action: str
    old_state: Optional[str] = None
    new_state: Optional[str] = None
    reason: Optional[str] = None
    timestamp: datetime


# Memory, Brief, and Search Schemas
class BriefResponse(BaseModel):
    project_id: str
    user_id: str
    spoken_script: str
    generated_at: datetime
    latest_decisions_count: int
    pending_prerequisites_count: int
    assigned_tasks_count: int


class CitationSource(BaseModel):
    meeting_id: str
    meeting_title: str
    timestamp_start_ms: int
    timestamp_end_ms: int
    quote: str


class SearchAnswerResponse(BaseModel):
    query: str
    answer: str
    citations: List[CitationSource] = Field(default_factory=list)


class NotificationResponse(BaseModel):
    id: str
    project_id: str
    title: str
    message: str
    type: str
    is_read: bool
    created_at: datetime
