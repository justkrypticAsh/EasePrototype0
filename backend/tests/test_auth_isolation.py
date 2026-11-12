"""Unit and Integration tests for Phase 3: Auth & Project Isolation."""

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
async def test_signup_and_login():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. Signup
        signup_payload = {
            "email": "ashish@ease.internal",
            "password": "SuperSecretPassword123!",
            "full_name": "Ashish Sharma"
        }
        resp = await client.post("/api/v1/auth/signup", json=signup_payload)
        assert resp.status_code == 201
        data = resp.json()
        assert "access_token" in data
        assert data["email"] == "ashish@ease.internal"

        # 2. Login
        login_payload = {
            "email": "ashish@ease.internal",
            "password": "SuperSecretPassword123!"
        }
        login_resp = await client.post("/api/v1/auth/login", json=login_payload)
        assert login_resp.status_code == 200
        assert "access_token" in login_resp.json()


@pytest.mark.asyncio
async def test_strict_multi_tenant_project_isolation():
    """
    Proves that:
    1. A non-member receives 403 FORBIDDEN when accessing another user's project.
    2. Data from Project A never appears in Project B query responses.
    """
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # Create User A
        u1_resp = await client.post("/api/v1/auth/signup", json={
            "email": "user_a@ease.internal",
            "password": "PasswordUserA123!",
            "full_name": "Alice User"
        })
        token_a = u1_resp.json()["access_token"]
        headers_a = {"Authorization": f"Bearer {token_a}"}

        # Create User B
        u2_resp = await client.post("/api/v1/auth/signup", json={
            "email": "user_b@ease.internal",
            "password": "PasswordUserB123!",
            "full_name": "Bob User"
        })
        token_b = u2_resp.json()["access_token"]
        headers_b = {"Authorization": f"Bearer {token_b}"}

        # User A creates Project Alpha
        p_alpha_resp = await client.post(
            "/api/v1/projects",
            json={"name": "Project Alpha", "domain": "consulting"},
            headers=headers_a
        )
        assert p_alpha_resp.status_code == 201
        project_alpha_id = p_alpha_resp.json()["id"]

        # User B creates Project Beta
        p_beta_resp = await client.post(
            "/api/v1/projects",
            json={"name": "Project Beta", "domain": "startup"},
            headers=headers_b
        )
        assert p_beta_resp.status_code == 201
        project_beta_id = p_beta_resp.json()["id"]

        # 1. User B tries to read Project Alpha -> Must get 403 Forbidden!
        forbidden_resp = await client.get(
            f"/api/v1/projects/{project_alpha_id}",
            headers=headers_b
        )
        assert forbidden_resp.status_code == 403
        assert "Access denied" in forbidden_resp.json()["detail"]

        # 2. User B tries to list meetings of Project Alpha -> Must get 403 Forbidden!
        meetings_forbidden = await client.get(
            f"/api/v1/projects/{project_alpha_id}/meetings",
            headers=headers_b
        )
        assert meetings_forbidden.status_code == 403

        # 3. User B lists their own projects -> Project Alpha MUST NOT appear!
        my_projects_resp = await client.get("/api/v1/projects", headers=headers_b)
        assert my_projects_resp.status_code == 200
        my_project_ids = [p["id"] for p in my_projects_resp.json()]
        assert project_beta_id in my_project_ids
        assert project_alpha_id not in my_project_ids
