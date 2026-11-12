"""Shareable Server-Rendered HTML Report Endpoints."""

import secrets
from datetime import datetime, timedelta, timezone
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.api.deps import require_project_membership
from backend.app.database import get_db
from backend.app.models.extraction import Claim, Decision, Prerequisite
from backend.app.models.meeting import Meeting, Segment
from backend.app.models.project import Project, ProjectMember

router = APIRouter(tags=["Reports"])

# Ephemeral share tokens: token -> {meeting_id, expires_at}
_SHARE_TOKENS = {}


@router.post("/projects/{project_id}/meetings/{meeting_id}/share")
async def generate_share_link(
    project_id: str,
    meeting_id: str,
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """Generates an expiring shareable link for viewing meeting report in a browser."""
    meeting = await db.get(Meeting, meeting_id)
    if not meeting or meeting.project_id != project_id:
        raise HTTPException(status_code=404, detail="Meeting not found")

    token = secrets.token_urlsafe(24)
    expires_at = datetime.now(timezone.utc) + timedelta(days=3)
    _SHARE_TOKENS[token] = {
        "meeting_id": meeting_id,
        "project_id": project_id,
        "expires_at": expires_at
    }

    return {
        "share_url": f"/reports/view/{token}",
        "token": token,
        "expires_at": expires_at
    }


@router.get("/reports/view/{token}", response_class=HTMLResponse)
async def view_shared_report(token: str, db: Annotated[AsyncSession, Depends(get_db)]):
    record = _SHARE_TOKENS.get(token)
    if not record:
        raise HTTPException(status_code=404, detail="Share link is invalid")

    expiry = record["expires_at"]
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)

    if expiry < datetime.now(timezone.utc):
        raise HTTPException(status_code=404, detail="Share link is invalid or expired")

    meeting = await db.get(Meeting, record["meeting_id"])
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")

    project = await db.get(Project, record["project_id"])
    project_name = project.name if project else "Project"

    claims = (await db.execute(select(Claim).where(Claim.meeting_id == meeting.id))).scalars().all()
    decisions = (await db.execute(select(Decision).where(Decision.meeting_id == meeting.id))).scalars().all()
    prereqs = (await db.execute(select(Prerequisite).where(Prerequisite.meeting_id == meeting.id))).scalars().all()
    segments = (await db.execute(select(Segment).where(Segment.meeting_id == meeting.id).order_by(Segment.start_ms))).scalars().all()

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>EASE Report: {meeting.title}</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0b0f19; color: #f1f5f9; margin: 0; padding: 2rem; }}
    .container {{ max-width: 800px; margin: 0 auto; background: #1e293b; padding: 2rem; border-radius: 12px; border: 1px solid #334155; }}
    h1 {{ color: #38bdf8; margin-top: 0; }}
    .meta {{ font-size: 0.9rem; color: #94a3b8; margin-bottom: 1.5rem; }}
    .section {{ margin-top: 2rem; }}
    .section h2 {{ border-bottom: 1px solid #334155; padding-bottom: 0.5rem; color: #e2e8f0; font-size: 1.2rem; }}
    .item {{ background: #0f172a; padding: 0.75rem 1rem; border-radius: 6px; margin-bottom: 0.5rem; border-left: 3px solid #38bdf8; }}
    .badge {{ font-size: 0.75rem; text-transform: uppercase; padding: 2px 6px; border-radius: 4px; background: #0369a1; color: #fff; margin-right: 6px; }}
    .transcript-line {{ font-size: 0.9rem; margin-bottom: 0.5rem; }}
    .speaker {{ font-weight: 600; color: #38bdf8; }}
    .time {{ color: #64748b; font-size: 0.8rem; margin-right: 6px; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="meta">{project_name} &bull; Recorded on {meeting.created_at.strftime('%Y-%m-%d %H:%M UTC')}</div>
    <h1>{meeting.title}</h1>
    <div class="meta">Duration: {meeting.audio_duration_seconds:.1f}s &bull; Status: {meeting.status.upper()}</div>

    <div class="section">
      <h2>Executive Summary</h2>
      <p>{meeting.summary or 'Summary processing...'}</p>
    </div>

    <div class="section">
      <h2>Decisions ({len(decisions)})</h2>
      {"".join(f'<div class="item">&#10003; {d.text}</div>' for d in decisions) or '<p>No decisions extracted.</p>'}
    </div>

    <div class="section">
      <h2>Claims & Commitments ({len(claims)})</h2>
      {"".join(f'<div class="item"><span class="badge">{c.type}</span> <strong>{c.speaker_label}:</strong> "{c.text}"</div>' for c in claims) or '<p>No claims extracted.</p>'}
    </div>

    <div class="section">
      <h2>Prerequisites & Follow-ups ({len(prereqs)})</h2>
      {"".join(f'<div class="item"><span class="badge">{p.status}</span> {p.text} {"(Depends on: " + p.depends_on + ")" if p.depends_on else ""}</div>' for p in prereqs) or '<p>No prerequisites extracted.</p>'}
    </div>

    <div class="section">
      <h2>Transcript</h2>
      {"".join(f'<div class="transcript-line"><span class="time">[{s.start_ms//1000}s]</span> <span class="speaker">{s.speaker_label}:</span> {s.text}</div>' for s in segments) or '<p>No transcript segments available.</p>'}
    </div>
  </div>
</body>
</html>
    """
    return HTMLResponse(content=html)
