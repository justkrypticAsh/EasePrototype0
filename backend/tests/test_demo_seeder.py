"""Test Demonstration Dataset Seeder and Reset Endpoint."""

import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy import select

from backend.app.database import Base, engine, AsyncSessionLocal
from backend.app.main import app
from backend.app.models.project import Project, ProjectMember
from backend.app.models.extraction import Prerequisite
from backend.app.services.demo_seeder import seed_demo_data_if_needed


@pytest.fixture(autouse=True)
async def setup_test_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.mark.asyncio
async def test_demo_seeder_populates_product_launch_dataset():
    async with AsyncSessionLocal() as session:
        await seed_demo_data_if_needed(session)

        # Verify project exists
        stmt = select(Project).where(Project.id == "project-product-launch")
        proj = (await session.execute(stmt)).scalar_one_or_none()
        assert proj is not None
        assert proj.name == "Product Launch"
        assert proj.domain == "startup"

        # Verify members: Aarav, Riya, Kabir, Neha
        m_stmt = select(ProjectMember).where(ProjectMember.project_id == proj.id)
        members = (await session.execute(m_stmt)).scalars().all()
        apple_ids = {m.apple_id for m in members if m.apple_id}
        assert "aarav.mehta@icloud.com" in apple_ids
        assert "riya.sharma@icloud.com" in apple_ids
        assert "kabir.singh@icloud.com" in apple_ids
        assert "neha.kapoor@icloud.com" in apple_ids

        # Verify blocker dependency chain
        p_stmt = select(Prerequisite).where(Prerequisite.project_id == proj.id)
        tasks = (await session.execute(p_stmt)).scalars().all()
        blocked_tasks = [t for t in tasks if t.depends_on_task_id is not None]
        assert len(blocked_tasks) >= 1
        assert blocked_tasks[0].blocked_by_user_name == "Riya Sharma"


@pytest.mark.asyncio
async def test_demo_reset_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/api/v1/demo/reset")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "success"
