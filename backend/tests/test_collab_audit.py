"""Unit tests for Phase 5 Collaboration, Audit Logs, and Consent Enforcement."""

import pytest
from httpx import ASGITransport, AsyncClient
from backend.app.database import Base, engine
from backend.app.main import app


@pytest.fixture(autouse=True)
async def setup_test_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.mark.asyncio
async def test_assignment_and_audit_logging():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # Create Owner
        owner_resp = await client.post("/api/v1/auth/signup", json={
            "email": "owner@ease.internal",
            "password": "Password123!",
            "full_name": "Project Owner"
        })
        owner_token = owner_resp.json()["access_token"]
        owner_headers = {"Authorization": f"Bearer {owner_token}"}

        # Create Member
        member_resp = await client.post("/api/v1/auth/signup", json={
            "email": "member@ease.internal",
            "password": "Password123!",
            "full_name": "Team Member"
        })
        member_id = member_resp.json()["user_id"]
        member_token = member_resp.json()["access_token"]
        member_headers = {"Authorization": f"Bearer {member_token}"}

        # Create Project
        proj_resp = await client.post("/api/v1/projects", json={"name": "Collab Project"}, headers=owner_headers)
        proj_id = proj_resp.json()["id"]

        # Invite Member & Accept
        inv_resp = await client.post(f"/api/v1/projects/{proj_id}/invites", json={"max_uses": 1}, headers=owner_headers)
        code = inv_resp.json()["code"]
        await client.post(f"/api/v1/invites/{code}/accept", headers=member_headers)

        # Upload meeting (with mock wav bytes)
        fake_wav = b"RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00@\x1f\x00\x00\x80>\x00\x00\x02\x00\x10\x00data\x00\x00\x00\x00"
        files = {"file": ("test.wav", fake_wav, "audio/wav")}
        data = {
            "title": "Strategy Sync",
            "participants": '["Project Owner", "Team Member"]',
            "spoken_announcement_played": "true",
            "all_consented": "true",
            "declined_participants": "[]"
        }
        meeting_resp = await client.post(
            f"/api/v1/projects/{proj_id}/meetings/upload",
            data=data,
            files=files,
            headers=owner_headers
        )
        assert meeting_resp.status_code == 202
        meeting_id = meeting_resp.json()["id"]

        # Directly insert a prerequisite for testing assignment
        from backend.app.database import AsyncSessionLocal
        from backend.app.models.extraction import Prerequisite
        async with AsyncSessionLocal() as session:
            prereq = Prerequisite(
                meeting_id=meeting_id,
                project_id=proj_id,
                text="Draft terms sheet",
                timestamp_start_ms=100,
                timestamp_end_ms=500
            )
            session.add(prereq)
            await session.commit()
            prereq_id = prereq.id

        # 1. Assign to Member
        assign_resp = await client.patch(
            f"/api/v1/projects/{proj_id}/items/prerequisite/{prereq_id}/assign",
            json={"owner_user_id": member_id},
            headers=owner_headers
        )
        assert assign_resp.status_code == 200

        # 2. Member updates status to confirmed
        status_resp = await client.patch(
            f"/api/v1/projects/{proj_id}/items/prerequisite/{prereq_id}/status",
            json={"status": "confirmed", "reason": "I accept this task"},
            headers=member_headers
        )
        assert status_resp.status_code == 200
        assert status_resp.json()["status"] == "confirmed"

        # 3. Check Audit Logs
        audit_resp = await client.get(f"/api/v1/projects/{proj_id}/audit", headers=owner_headers)
        assert audit_resp.status_code == 200
        logs = audit_resp.json()
        assert len(logs) >= 2
        actions = [l["action"] for l in logs]
        assert "assign" in actions
        assert "status_change" in actions


@pytest.mark.asyncio
async def test_declined_consent_aborts_recording():
    """Proves that if any participant declines consent, recording is blocked."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # Create User & Project
        u_resp = await client.post("/api/v1/auth/signup", json={
            "email": "lead@ease.internal",
            "password": "Password123!",
            "full_name": "Project Lead"
        })
        token = u_resp.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        p_resp = await client.post("/api/v1/projects", json={"name": "Privacy Project"}, headers=headers)
        proj_id = p_resp.json()["id"]

        fake_wav = b"RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00@\x1f\x00\x00\x80>\x00\x00\x02\x00\x10\x00data\x00\x00\x00\x00"
        files = {"file": ("test.wav", fake_wav, "audio/wav")}

        # One participant declined
        declined_data = {
            "title": "Sync with unconsented member",
            "participants": '["Lead", "Guest"]',
            "spoken_announcement_played": "true",
            "all_consented": "false",
            "declined_participants": '["Guest"]'
        }
        res = await client.post(
            f"/api/v1/projects/{proj_id}/meetings/upload",
            data=declined_data,
            files=files,
            headers=headers
        )
        assert res.status_code == 400
        assert "Consent was declined" in res.json()["detail"]
