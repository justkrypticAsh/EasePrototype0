"""Unit tests for Phase 4 Cross-Discussion Memory, Relations & Scoping."""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession
from backend.app.database import Base, engine, AsyncSessionLocal
from backend.app.models.extraction import Claim, Decision, Prerequisite
from backend.app.models.meeting import Meeting
from backend.app.models.project import Project
from backend.app.services.memory_engine import MemoryEngine, RelationJudgeResult
from backend.tests.conftest import MockEmbeddingAdapter, MockLLMAdapter


@pytest.fixture(autouse=True)
async def setup_test_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.mark.asyncio
async def test_cross_discussion_relation_detection():
    async with AsyncSessionLocal() as session:
        # Create Project 1
        p1 = Project(name="Project Alpha", domain="consulting")
        session.add(p1)
        await session.flush()

        # Meeting 1: sets a prerequisite
        m1 = Meeting(project_id=p1.id, created_by_user_id="u1", title="Meeting 1", audio_filename="m1.wav", status="ready")
        session.add(m1)
        await session.flush()

        prereq1 = Prerequisite(
            meeting_id=m1.id,
            project_id=p1.id,
            text="Need client sign-off on security architecture",
            depends_on="Security Review",
            status="open",
            timestamp_start_ms=1000,
            timestamp_end_ms=3000
        )
        session.add(prereq1)
        await session.commit()

        # Meeting 2: resolves the prerequisite
        m2 = Meeting(project_id=p1.id, created_by_user_id="u1", title="Meeting 2", audio_filename="m2.wav", status="ready")
        session.add(m2)
        await session.flush()

        claim2 = Claim(
            meeting_id=m2.id,
            project_id=p1.id,
            text="Client has signed off on the security architecture today",
            speaker_label="Speaker 0",
            timestamp_start_ms=2000,
            timestamp_end_ms=4000,
            type="fact_claim",
            confidence=0.98
        )
        session.add(claim2)
        await session.commit()

        # Mock LLM Judge returning RESOLVES_PREREQUISITE
        judge_mock = RelationJudgeResult(
            relation="RESOLVES_PREREQUISITE",
            short_reason="Client sign-off was confirmed in meeting 2",
            judge_confidence=0.95
        )
        mock_llm = MockLLMAdapter(response_queue=[judge_mock])
        memory_engine = MemoryEngine(MockEmbeddingAdapter(), mock_llm)

        # First embed Meeting 1 items
        await memory_engine.link_meeting_items(p1.id, m1.id, session)

        # Now link Meeting 2 items
        links = await memory_engine.link_meeting_items(p1.id, m2.id, session)

        assert len(links) >= 1
        assert links[0].relation == "RESOLVES_PREREQUISITE"
        assert links[0].needs_review is False

        # Verify prerequisite status was automatically unblocked and set to 'done'
        updated_prereq = await session.get(Prerequisite, prereq1.id)
        assert updated_prereq.status == "done"


@pytest.mark.asyncio
async def test_memory_linking_never_crosses_projects():
    """Proves that items from Project A are NEVER linked to items from Project B."""
    async with AsyncSessionLocal() as session:
        # Create Project A
        p_a = Project(name="Project A")
        p_b = Project(name="Project B")
        session.add_all([p_a, p_b])
        await session.flush()

        m_a = Meeting(project_id=p_a.id, created_by_user_id="u1", title="M_A", audio_filename="a.wav", status="ready")
        m_b = Meeting(project_id=p_b.id, created_by_user_id="u2", title="M_B", audio_filename="b.wav", status="ready")
        session.add_all([m_a, m_b])
        await session.flush()

        # Identical text in both projects
        d_a = Decision(meeting_id=m_a.id, project_id=p_a.id, text="Deploy to AWS us-east-1", timestamp_start_ms=0, timestamp_end_ms=1000)
        d_b = Decision(meeting_id=m_b.id, project_id=p_b.id, text="Deploy to AWS us-east-1", timestamp_start_ms=0, timestamp_end_ms=1000)
        session.add_all([d_a, d_b])
        await session.commit()

        mock_llm = MockLLMAdapter()
        memory_engine = MemoryEngine(MockEmbeddingAdapter(), mock_llm)

        # Process Project A
        await memory_engine.link_meeting_items(p_a.id, m_a.id, session)

        # Process Project B
        links_b = await memory_engine.link_meeting_items(p_b.id, m_b.id, session)

        # Project B has only one meeting; it must NEVER link to Project A's meeting!
        assert len(links_b) == 0
