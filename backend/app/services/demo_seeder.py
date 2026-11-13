"""Demonstration Dataset Seeder for EASE.

Seeds the sample project 'Product Launch' with team members Aarav Mehta (Owner),
Riya Sharma (Editor), Kabir Singh (Contributor), and Neha Kapoor (Viewer), along with
sample discussions, diarized transcripts, decisions, claims, and cross-collaborator blocker chains.
"""

import json
from datetime import datetime, timezone, timedelta
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.models.user import User
from backend.app.models.project import Project, ProjectMember
from backend.app.models.meeting import Meeting, Participant, ConsentRecord, Segment
from backend.app.models.extraction import Decision, Claim, Prerequisite
from backend.app.models.memory import Link


async def seed_demo_data_if_needed(db: AsyncSession):
    """Checks if the demo project exists; if not, seeds it."""
    stmt = select(Project).where(Project.id == "project-product-launch")
    res = await db.execute(stmt)
    existing = res.scalar_one_or_none()
    if existing is not None:
        return

    await seed_demo_data(db)


async def seed_demo_data(db: AsyncSession):
    """Populates the database with the complete 'Product Launch' demo dataset."""
    now = datetime.now(timezone.utc)

    # 1. Users
    users_data = [
        {
            "id": "dev-user-001",
            "email": "ashish@ease.ai",
            "full_name": "Ashish Sharma",
            "hashed_password": "demo_hashed_password"
        },
        {
            "id": "user-aarav",
            "email": "aarav.mehta@icloud.com",
            "full_name": "Aarav Mehta",
            "hashed_password": "demo_hashed_password"
        },
        {
            "id": "user-riya",
            "email": "riya.sharma@icloud.com",
            "full_name": "Riya Sharma",
            "hashed_password": "demo_hashed_password"
        },
        {
            "id": "user-kabir",
            "email": "kabir.singh@icloud.com",
            "full_name": "Kabir Singh",
            "hashed_password": "demo_hashed_password"
        },
        {
            "id": "user-neha",
            "email": "neha.kapoor@icloud.com",
            "full_name": "Neha Kapoor",
            "hashed_password": "demo_hashed_password"
        }
    ]

    for u in users_data:
        stmt = select(User).where(User.id == u["id"])
        existing_u = (await db.execute(stmt)).scalar_one_or_none()
        if not existing_u:
            user_obj = User(
                id=u["id"],
                email=u["email"],
                full_name=u["full_name"],
                hashed_password=u["hashed_password"],
                is_active=True,
                created_at=now - timedelta(days=10)
            )
            db.add(user_obj)
    await db.flush()

    # 2. Project
    project = Project(
        id="project-product-launch",
        name="Product Launch",
        description="Flagship Q1 Product Launch: Multi-Platform AI Memory & Collaboration.",
        domain="startup",
        language_code="auto",
        recording_policy_text="All discussions require explicit affirmative consent. Diarization and biometric enrollment enabled.",
        created_at=now - timedelta(days=5)
    )
    db.add(project)
    await db.flush()

    # 3. Project Members
    memberships = [
        {"user_id": "user-aarav", "apple_id": "aarav.mehta@icloud.com", "role": "owner"},
        {"user_id": "dev-user-001", "apple_id": "ashish@ease.ai", "role": "owner"},
        {"user_id": "user-riya", "apple_id": "riya.sharma@icloud.com", "role": "editor"},
        {"user_id": "user-kabir", "apple_id": "kabir.singh@icloud.com", "role": "contributor"},
        {"user_id": "user-neha", "apple_id": "neha.kapoor@icloud.com", "role": "viewer"},
    ]
    for m in memberships:
        mem = ProjectMember(
            project_id=project.id,
            user_id=m["user_id"],
            apple_id=m["apple_id"],
            role=m["role"],
            policy_accepted_at=now - timedelta(days=5),
            joined_at=now - timedelta(days=5)
        )
        db.add(mem)
    await db.flush()

    # 4. Meeting 1: Architecture & Scope Kickoff
    m1 = Meeting(
        id="meeting-launch-001",
        project_id=project.id,
        created_by_user_id="user-aarav",
        title="Product Launch Architecture & Scope",
        audio_filename="launch_kickoff.wav",
        audio_duration_seconds=480.0,
        status="ready",
        cost_audio_minutes=8.0,
        cost_llm_tokens=1820,
        summary=(
            "Strategic kickoff on Product Launch: Approved Gemini Flash 1.5 as default inference model "
            "with <1.2s SLA. Mandated AES-256 local biometric voice vault on iOS with zero unencrypted transmission. "
            "Established cross-collaborator dependency: Kabir's PostgreSQL sharding deployment is blocked by "
            "Riya's Client Security Architecture sign-off."
        ),
        created_at=now - timedelta(days=3)
    )
    db.add(m1)
    await db.flush()

    # Consent Record 1
    c1 = ConsentRecord(
        id="consent-launch-001",
        meeting_id=m1.id,
        project_id=project.id,
        participants_json=json.dumps(["Aarav Mehta", "Riya Sharma", "Kabir Singh"]),
        confirmed_by_json=json.dumps(["Aarav Mehta", "Riya Sharma", "Kabir Singh"]),
        spoken_announcement_played=True,
        any_declined=False,
        timestamp=now - timedelta(days=3)
    )
    db.add(c1)

    # Participants
    for name, uid in [("Aarav Mehta", "user-aarav"), ("Riya Sharma", "user-riya"), ("Kabir Singh", "user-kabir")]:
        db.add(Participant(meeting_id=m1.id, user_id=uid, name=name, consented=True, consent_timestamp=now - timedelta(days=3)))

    # Diarized Segments
    segments = [
        Segment(
            meeting_id=m1.id,
            project_id=project.id,
            speaker_label="Aarav Mehta",
            start_ms=0,
            end_ms=14000,
            text="Welcome team. Let's align on the Q1 launch deliverables, AI stack, and dependencies.",
            confidence=0.98
        ),
        Segment(
            meeting_id=m1.id,
            project_id=project.id,
            speaker_label="Riya Sharma",
            start_ms=14200,
            end_ms=32000,
            text="Gemini Flash benchmarks show consistent 1.1s round-trip response time, well within our 1.2s SLA.",
            confidence=0.96
        ),
        Segment(
            meeting_id=m1.id,
            project_id=project.id,
            speaker_label="Kabir Singh",
            start_ms=32200,
            end_ms=55000,
            text="I'm ready for the database migration, but I need Riya to sign off on the client security architecture before touching production.",
            confidence=0.94
        ),
        Segment(
            meeting_id=m1.id,
            project_id=project.id,
            speaker_label="Aarav Mehta",
            start_ms=55200,
            end_ms=75000,
            text="Agreed. Let's record that blocker: Kabir is blocked until Riya delivers the security sign-off.",
            confidence=0.97
        ),
    ]
    for seg in segments:
        db.add(seg)

    # Decisions
    dec1 = Decision(
        id="dec-launch-001",
        meeting_id=m1.id,
        project_id=project.id,
        text="Adopt Gemini Flash 1.5 for sub-1.2s discussion intelligence",
        decided_by="Aarav Mehta",
        timestamp_start_ms=14200,
        timestamp_end_ms=32000,
        created_at=now - timedelta(days=3)
    )
    dec2 = Decision(
        id="dec-launch-002",
        meeting_id=m1.id,
        project_id=project.id,
        text="Enforce AES-256 encrypted local biometric voice vault on iOS",
        decided_by="Aarav Mehta",
        timestamp_start_ms=55200,
        timestamp_end_ms=75000,
        created_at=now - timedelta(days=3)
    )
    db.add(dec1)
    db.add(dec2)

    # Claims
    claim1 = Claim(
        id="claim-launch-001",
        meeting_id=m1.id,
        project_id=project.id,
        text="Gemini Flash meets 1.2s round-trip latency SLA",
        speaker_label="Riya Sharma",
        type="fact_claim",
        confidence=0.98,
        timestamp_start_ms=14200,
        timestamp_end_ms=32000,
        status="confirmed",
        created_at=now - timedelta(days=3)
    )
    claim2 = Claim(
        id="claim-launch-002",
        meeting_id=m1.id,
        project_id=project.id,
        text="Production database sharding requires 48 hours migration window",
        speaker_label="Kabir Singh",
        type="estimate",
        confidence=0.91,
        timestamp_start_ms=32200,
        timestamp_end_ms=55000,
        status="open",
        created_at=now - timedelta(days=3)
    )
    db.add(claim1)
    db.add(claim2)

    # Prerequisites & Tasks (with Blocker Chain)
    task1 = Prerequisite(
        id="task-launch-001",
        meeting_id=m1.id,
        project_id=project.id,
        text="Finalize Client Security Architecture & Sign-off",
        owner_mentioned="Riya Sharma",
        owner_user_id="user-riya",
        depends_on=None,
        depends_on_task_id=None,
        blocked_by_user_name=None,
        blocked_by_apple_id=None,
        status="open",
        timestamp_start_ms=32200,
        timestamp_end_ms=55000,
        created_at=now - timedelta(days=3)
    )
    db.add(task1)
    await db.flush()

    task2 = Prerequisite(
        id="task-launch-002",
        meeting_id=m1.id,
        project_id=project.id,
        text="Deploy Production PostgreSQL Sharding & Migration",
        owner_mentioned="Kabir Singh",
        owner_user_id="user-kabir",
        depends_on="Finalize Client Security Architecture & Sign-off",
        depends_on_task_id=task1.id,
        blocked_by_user_name="Riya Sharma",
        blocked_by_apple_id="riya.sharma@icloud.com",
        status="open",
        timestamp_start_ms=32200,
        timestamp_end_ms=55000,
        created_at=now - timedelta(days=3)
    )
    task3 = Prerequisite(
        id="task-launch-003",
        meeting_id=m1.id,
        project_id=project.id,
        text="Draft Biometric Consent Protocol Agreement",
        owner_mentioned="Aarav Mehta",
        owner_user_id="user-aarav",
        depends_on=None,
        status="done",
        timestamp_start_ms=55200,
        timestamp_end_ms=75000,
        created_at=now - timedelta(days=3)
    )
    task4 = Prerequisite(
        id="task-launch-004",
        meeting_id=m1.id,
        project_id=project.id,
        text="App Store Submission Checklist & Product Screenshots",
        owner_mentioned="Neha Kapoor",
        owner_user_id="user-neha",
        depends_on=None,
        status="open",
        timestamp_start_ms=0,
        timestamp_end_ms=14000,
        created_at=now - timedelta(days=3)
    )
    db.add(task2)
    db.add(task3)
    db.add(task4)

    # 5. Meeting 2: Security Audit & Launch Readiness
    m2 = Meeting(
        id="meeting-launch-002",
        project_id=project.id,
        created_by_user_id="user-aarav",
        title="Security Audit & Launch Readiness",
        audio_filename="security_audit.wav",
        audio_duration_seconds=360.0,
        status="ready",
        cost_audio_minutes=6.0,
        cost_llm_tokens=1450,
        summary=(
            "Reviewed end-to-end security compliance for iOS release. Verified zero unconsented audio "
            "transmission policy. Confirmed that Gemini Flash analysis pipeline passes privacy audit."
        ),
        created_at=now - timedelta(days=1)
    )
    db.add(m2)
    await db.flush()

    c2 = ConsentRecord(
        id="consent-launch-002",
        meeting_id=m2.id,
        project_id=project.id,
        participants_json=json.dumps(["Aarav Mehta", "Neha Kapoor"]),
        confirmed_by_json=json.dumps(["Aarav Mehta", "Neha Kapoor"]),
        spoken_announcement_played=True,
        any_declined=False,
        timestamp=now - timedelta(days=1)
    )
    db.add(c2)

    for name, uid in [("Aarav Mehta", "user-aarav"), ("Neha Kapoor", "user-neha")]:
        db.add(Participant(meeting_id=m2.id, user_id=uid, name=name, consented=True, consent_timestamp=now - timedelta(days=1)))

    dec3 = Decision(
        id="dec-launch-003",
        meeting_id=m2.id,
        project_id=project.id,
        text="Confirmed zero unconsented audio transmission policy and instant purge option",
        decided_by="Aarav Mehta",
        timestamp_start_ms=5000,
        timestamp_end_ms=22000,
        created_at=now - timedelta(days=1)
    )
    db.add(dec3)
    await db.flush()

    # Memory Link: dec3 CONFIRMS dec2
    link1 = Link(
        id="link-launch-001",
        project_id=project.id,
        old_item_id=dec2.id,
        old_item_type="decision",
        new_item_id=dec3.id,
        new_item_type="decision",
        relation="CONFIRMS",
        short_reason="Re-affirms AES-256 local vault encryption policy agreed in kickoff meeting.",
        similarity=0.92,
        judge_confidence=0.96,
        needs_review=False,
        created_at=now - timedelta(days=1)
    )
    db.add(link1)

    await db.commit()


async def reset_demo_data(db: AsyncSession):
    """Deletes existing demo project and re-seeds it cleanly."""
    stmt = select(Project).where(Project.id == "project-product-launch")
    res = await db.execute(stmt)
    existing = res.scalar_one_or_none()
    if existing:
        # Delete related items
        p_id = existing.id
        await db.execute(delete(Link).where(Link.project_id == p_id))
        await db.execute(delete(Prerequisite).where(Prerequisite.project_id == p_id))
        await db.execute(delete(Claim).where(Claim.project_id == p_id))
        await db.execute(delete(Decision).where(Decision.project_id == p_id))
        await db.execute(delete(Segment).where(Segment.project_id == p_id))
        await db.execute(delete(ConsentRecord).where(ConsentRecord.project_id == p_id))
        await db.execute(delete(Participant).where(Participant.meeting_id.in_(
            select(Meeting.id).where(Meeting.project_id == p_id)
        )))
        await db.execute(delete(Meeting).where(Meeting.project_id == p_id))
        await db.execute(delete(ProjectMember).where(ProjectMember.project_id == p_id))
        await db.execute(delete(Project).where(Project.id == p_id))
        await db.commit()

    await seed_demo_data(db)
