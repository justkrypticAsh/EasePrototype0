"""Meeting Ingestion, Consent Records, and Processing Status REST Endpoints."""

import json
import os
import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated, List, Optional
from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.api.deps import (
    get_current_user,
    require_project_membership,
    require_project_owner
)
from backend.app.config import get_settings
from backend.app.database import AsyncSessionLocal, get_db
from backend.app.models.extraction import Claim, Decision, Prerequisite
from backend.app.models.meeting import ConsentRecord, Meeting, Participant, Segment
from backend.app.models.memory import Link, MemoryEmbedding
from backend.app.models.project import ProjectMember
from backend.app.models.user import User
from backend.app.schemas.api import MeetingStatusResponse
from backend.app.services.audio_normalizer import AudioNormalizer
from backend.app.services.pipeline import MeetingPipelineOrchestrator

router = APIRouter(tags=["Meetings"])
settings = get_settings()


async def run_pipeline_background(meeting_id: str, audio_path: str):
    """Background task runner opening its own async db session."""
    async with AsyncSessionLocal() as session:
        orchestrator = MeetingPipelineOrchestrator()
        await orchestrator.process_meeting(meeting_id, audio_path, session)


@router.post("/projects/{project_id}/meetings/upload", response_model=MeetingStatusResponse, status_code=status.HTTP_202_ACCEPTED)
async def upload_meeting(
    project_id: str,
    background_tasks: BackgroundTasks,
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: UploadFile = File(...),
    title: str = Form(...),
    participants: str = Form(..., description="JSON list of participant names"),
    spoken_announcement_played: bool = Form(False),
    all_consented: bool = Form(True),
    declined_participants: str = Form("[]", description="JSON list of names who declined")
):
    """
    Ingests meeting audio with mandatory affirmative participant consent.
    If consent is incomplete or any participant declined, recording is aborted.
    """
    try:
        part_list = json.loads(participants)
        decl_list = json.loads(declined_participants)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON for participants or declined_participants")

    if not all_consented or len(decl_list) > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Recording cannot start or be processed: Consent was declined or unconfirmed by participants."
        )

    # Save audio upload
    storage_dir = Path(settings.AUDIO_STORAGE_PATH)
    storage_dir.mkdir(parents=True, exist_ok=True)

    file_ext = Path(file.filename).suffix.lower() if file.filename else ".m4a"
    saved_filename = f"{uuid.uuid4()}{file_ext}"
    saved_path = storage_dir / saved_filename

    with open(saved_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Normalize audio
    normalizer = AudioNormalizer()
    normalized_path, duration = normalizer.normalize(str(saved_path))

    # Create Meeting
    meeting = Meeting(
        project_id=project_id,
        created_by_user_id=current_user.id,
        title=title.strip(),
        audio_filename=Path(normalized_path).name,
        audio_duration_seconds=duration,
        status="uploaded"
    )
    db.add(meeting)
    await db.flush()

    # Create immutable ConsentRecord
    consent_rec = ConsentRecord(
        meeting_id=meeting.id,
        project_id=project_id,
        participants_json=json.dumps(part_list),
        confirmed_by_json=json.dumps(part_list),
        spoken_announcement_played=spoken_announcement_played,
        any_declined=False,
        timestamp=datetime.now(timezone.utc)
    )
    db.add(consent_rec)

    for p_name in part_list:
        db.add(Participant(
            meeting_id=meeting.id,
            name=p_name,
            consented=True
        ))

    await db.commit()
    await db.refresh(meeting)

    # Queue background processing pipeline
    background_tasks.add_task(run_pipeline_background, meeting.id, normalized_path)

    return MeetingStatusResponse(
        id=meeting.id,
        project_id=meeting.project_id,
        title=meeting.title,
        status=meeting.status,
        audio_duration_seconds=meeting.audio_duration_seconds,
        cost_audio_minutes=meeting.cost_audio_minutes,
        cost_llm_tokens=meeting.cost_llm_tokens,
        failure_reason=meeting.failure_reason,
        created_at=meeting.created_at
    )


@router.get("/projects/{project_id}/meetings", response_model=List[MeetingStatusResponse])
async def list_meetings(
    project_id: str,
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    stmt = (
        select(Meeting)
        .where(Meeting.project_id == project_id)
        .order_by(Meeting.created_at.desc())
    )
    res = await db.execute(stmt)
    meetings = res.scalars().all()
    return [
        MeetingStatusResponse(
            id=m.id,
            project_id=m.project_id,
            title=m.title,
            status=m.status,
            audio_duration_seconds=m.audio_duration_seconds,
            cost_audio_minutes=m.cost_audio_minutes,
            cost_llm_tokens=m.cost_llm_tokens,
            failure_reason=m.failure_reason,
            created_at=m.created_at
        )
        for m in meetings
    ]


@router.get("/projects/{project_id}/meetings/{meeting_id}")
async def get_meeting_detail(
    project_id: str,
    meeting_id: str,
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    meeting = await db.get(Meeting, meeting_id)
    if not meeting or meeting.project_id != project_id:
        raise HTTPException(status_code=404, detail="Meeting not found")

    segments = (await db.execute(
        select(Segment).where(Segment.meeting_id == meeting_id).order_by(Segment.start_ms)
    )).scalars().all()

    claims = (await db.execute(
        select(Claim).where(Claim.meeting_id == meeting_id)
    )).scalars().all()

    decisions = (await db.execute(
        select(Decision).where(Decision.meeting_id == meeting_id)
    )).scalars().all()

    prereqs = (await db.execute(
        select(Prerequisite).where(Prerequisite.meeting_id == meeting_id)
    )).scalars().all()

    return {
        "meeting": {
            "id": meeting.id,
            "project_id": meeting.project_id,
            "title": meeting.title,
            "status": meeting.status,
            "audio_duration_seconds": meeting.audio_duration_seconds,
            "summary": meeting.summary,
            "failure_reason": meeting.failure_reason,
            "cost_audio_minutes": meeting.cost_audio_minutes,
            "cost_llm_tokens": meeting.cost_llm_tokens,
            "created_at": meeting.created_at
        },
        "transcript": [
            {
                "id": s.id,
                "speaker_label": s.speaker_label,
                "start_ms": s.start_ms,
                "end_ms": s.end_ms,
                "text": s.text,
                "confidence": s.confidence,
                "is_low_confidence": s.is_low_confidence,
                "is_overlapping": s.is_overlapping,
                "suggested_speaker_label": s.suggested_speaker_label,
                "reconciliation_reason": s.reconciliation_reason
            }
            for s in segments
        ],
        "claims": [
            {
                "id": c.id,
                "text": c.text,
                "speaker_label": c.speaker_label,
                "timestamp_start_ms": c.timestamp_start_ms,
                "timestamp_end_ms": c.timestamp_end_ms,
                "type": c.type,
                "confidence": c.confidence,
                "status": c.status,
                "owner_user_id": c.owner_user_id
            }
            for c in claims
        ],
        "decisions": [
            {
                "id": d.id,
                "text": d.text,
                "timestamp_start_ms": d.timestamp_start_ms,
                "timestamp_end_ms": d.timestamp_end_ms,
                "decided_by": d.decided_by
            }
            for d in decisions
        ],
        "prerequisites": [
            {
                "id": p.id,
                "text": p.text,
                "depends_on": p.depends_on,
                "owner_mentioned": p.owner_mentioned,
                "owner_user_id": p.owner_user_id,
                "status": p.status,
                "timestamp_start_ms": p.timestamp_start_ms,
                "timestamp_end_ms": p.timestamp_end_ms
            }
            for p in prereqs
        ]
    }


@router.delete("/projects/{project_id}/meetings/{meeting_id}")
async def delete_meeting(
    project_id: str,
    meeting_id: str,
    owner_membership: Annotated[ProjectMember, Depends(require_project_owner)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """Owner cascades cleanup of audio, transcript, derived items, links, and embeddings."""
    meeting = await db.get(Meeting, meeting_id)
    if not meeting or meeting.project_id != project_id:
        raise HTTPException(status_code=404, detail="Meeting not found")

    # Find item ids to delete corresponding embeddings and links
    claim_ids = (await db.execute(select(Claim.id).where(Claim.meeting_id == meeting_id))).scalars().all()
    prereq_ids = (await db.execute(select(Prerequisite.id).where(Prerequisite.meeting_id == meeting_id))).scalars().all()
    decision_ids = (await db.execute(select(Decision.id).where(Decision.meeting_id == meeting_id))).scalars().all()
    all_item_ids = list(claim_ids) + list(prereq_ids) + list(decision_ids)

    if all_item_ids:
        await db.execute(delete(Link).where(Link.old_item_id.in_(all_item_ids) | Link.new_item_id.in_(all_item_ids)))
        await db.execute(delete(MemoryEmbedding).where(MemoryEmbedding.item_id.in_(all_item_ids)))

    await db.execute(delete(Claim).where(Claim.meeting_id == meeting_id))
    await db.execute(delete(Prerequisite).where(Prerequisite.meeting_id == meeting_id))
    await db.execute(delete(Decision).where(Decision.meeting_id == meeting_id))
    await db.execute(delete(Segment).where(Segment.meeting_id == meeting_id))
    await db.execute(delete(Participant).where(Participant.meeting_id == meeting_id))
    await db.execute(delete(ConsentRecord).where(ConsentRecord.meeting_id == meeting_id))

    # Remove audio file from disk
    storage_dir = Path(settings.AUDIO_STORAGE_PATH)
    audio_file = storage_dir / meeting.audio_filename
    if audio_file.exists():
        try:
            audio_file.unlink()
        except Exception:
            pass

    await db.execute(delete(Meeting).where(Meeting.id == meeting_id))
    await db.commit()

    return {"message": f"Meeting {meeting_id} and all derived records permanently deleted"}
