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


@pytest.mark.asyncio
async def test_apple_id_collab_and_task_dependencies():
    """Tests Apple ID collaborator invite, iCloud report generation, and blocker dependencies."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # Create Owner
        owner_resp = await client.post("/api/v1/auth/signup", json={
            "email": "ashish@ease.internal",
            "password": "Password123!",
            "full_name": "Ashish Sharma"
        })
        owner_token = owner_resp.json()["access_token"]
        owner_headers = {"Authorization": f"Bearer {owner_token}"}

        # Create Project
        proj_resp = await client.post("/api/v1/projects", json={"name": "EASE Architecture"}, headers=owner_headers)
        proj_id = proj_resp.json()["id"]

        # 1. Add Collaborator via Apple ID / iCloud
        collab_resp = await client.post(
            f"/api/v1/projects/{proj_id}/collaborators",
            json={
                "apple_id": "priya.sharma@icloud.com",
                "full_name": "Priya Sharma",
                "role": "member"
            },
            headers=owner_headers
        )
        assert collab_resp.status_code == 201
        collab_data = collab_resp.json()
        assert collab_data["apple_id"] == "priya.sharma@icloud.com"
        assert collab_data["full_name"] == "Priya Sharma"
        priya_user_id = collab_data["user_id"]

        # 2. Add two prerequisites to test blocker chain:
        # Task 1: "Design OpenAPI Spec" (Owner: Priya)
        # Task 2: "Implement Client SDK" (Owner: Ashish, depends on Task 1)
        from backend.app.database import AsyncSessionLocal
        from backend.app.models.extraction import Prerequisite
        from backend.app.models.meeting import Meeting

        owner_id = owner_resp.json()["user_id"]
        async with AsyncSessionLocal() as session:
            m = Meeting(
                project_id=proj_id,
                created_by_user_id=owner_id,
                title="Sprint Planning",
                audio_filename="sprint_planning.wav",
                status="ready"
            )
            session.add(m)
            await session.flush()

            task1 = Prerequisite(
                meeting_id=m.id,
                project_id=proj_id,
                text="Design OpenAPI Spec",
                owner_user_id=priya_user_id,
                owner_mentioned="Priya Sharma",
                status="open",
                timestamp_start_ms=0,
                timestamp_end_ms=1000
            )
            session.add(task1)
            await session.flush()

            task2 = Prerequisite(
                meeting_id=m.id,
                project_id=proj_id,
                text="Implement Client SDK",
                owner_user_id=owner_resp.json()["user_id"],
                owner_mentioned="Ashish Sharma",
                depends_on="Design OpenAPI Spec",
                depends_on_task_id=task1.id,
                blocked_by_user_name="Priya Sharma",
                blocked_by_apple_id="priya.sharma@icloud.com",
                status="open",
                timestamp_start_ms=1000,
                timestamp_end_ms=2000
            )
            session.add(task2)
            await session.commit()
            task1_id = task1.id
            task2_id = task2.id

        # 3. Query Dependencies: Task 2 should be flagged is_blocked = True
        dep_resp = await client.get(f"/api/v1/projects/{proj_id}/dependencies", headers=owner_headers)
        assert dep_resp.status_code == 200
        deps = dep_resp.json()
        assert len(deps) == 2

        task2_dep = next(d for d in deps if d["id"] == task2_id)
        assert task2_dep["is_blocked"] is True
        assert task2_dep["blocked_by_user_name"] == "Priya Sharma"

        # 4. Nudge blocker collaborator
        nudge_resp = await client.post(
            f"/api/v1/projects/{proj_id}/tasks/{task2_id}/nudge",
            json={"message": "Priya, need OpenAPI spec to proceed with SDK"},
            headers=owner_headers
        )
        assert nudge_resp.status_code == 200
        assert "Nudge sent" in nudge_resp.json()["message"]

        # 5. Mark Task 1 done -> Task 2 becomes unblocked
        mark_done_resp = await client.patch(
            f"/api/v1/projects/{proj_id}/items/prerequisite/{task1_id}/status",
            json={"status": "done", "reason": "Spec published to repo"},
            headers=owner_headers
        )
        assert mark_done_resp.status_code == 200

        # Verify Task 2 is now unblocked
        dep_resp_after = await client.get(f"/api/v1/projects/{proj_id}/dependencies", headers=owner_headers)
        task2_after = next(d for d in dep_resp_after.json() if d["id"] == task2_id)
        assert task2_after["is_blocked"] is False

        # 6. Verify iCloud Reports export
        icloud_resp = await client.get(f"/api/v1/projects/{proj_id}/icloud/reports", headers=owner_headers)
        assert icloud_resp.status_code == 200
        icloud_data = icloud_resp.json()
        assert icloud_data["total_reports"] >= 1
        assert "iCloud Drive" in icloud_data["icloud_path"]
        assert len(icloud_data["reports"][0]["content_markdown"]) > 0
