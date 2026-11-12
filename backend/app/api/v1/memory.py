"""Cross-Discussion Memory, Briefing, and Q&A Search REST Endpoints."""

from typing import Annotated, List
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.api.deps import (
    get_current_user,
    require_project_membership
)
from backend.app.database import get_db
from backend.app.models.memory import Link
from backend.app.models.project import ProjectMember
from backend.app.models.user import User
from backend.app.schemas.api import BriefResponse, SearchAnswerResponse
from backend.app.services.memory_engine import MemoryEngine
from backend.app.adapters.embeddings.gemini import GeminiEmbeddingAdapter
from backend.app.adapters.llm.gemini import GeminiLLMAdapter

router = APIRouter(tags=["Project Memory"])


@router.get("/projects/{project_id}/links")
async def list_project_links(
    project_id: str,
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    stmt = select(Link).where(Link.project_id == project_id).order_by(Link.created_at.desc())
    links = (await db.execute(stmt)).scalars().all()
    return [
        {
            "id": l.id,
            "project_id": l.project_id,
            "old_item_id": l.old_item_id,
            "old_item_type": l.old_item_type,
            "new_item_id": l.new_item_id,
            "new_item_type": l.new_item_type,
            "relation": l.relation,
            "short_reason": l.short_reason,
            "similarity": l.similarity,
            "judge_confidence": l.judge_confidence,
            "needs_review": l.needs_review,
            "created_at": l.created_at
        }
        for l in links
    ]


@router.get("/projects/{project_id}/brief", response_model=BriefResponse)
async def get_project_brief(
    project_id: str,
    current_user: Annotated[User, Depends(get_current_user)],
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """
    Returns a personalized 60-90 second spoken-style briefing script
    tailored to the requesting member.
    """
    engine = MemoryEngine(GeminiEmbeddingAdapter(), GeminiLLMAdapter())
    brief_data = await engine.generate_user_brief(
        project_id=project_id,
        user_id=current_user.id,
        user_name=current_user.full_name,
        db=db
    )
    return BriefResponse(**brief_data)


@router.get("/projects/{project_id}/search", response_model=SearchAnswerResponse)
async def search_memory(
    project_id: str,
    q: Annotated[str, Query(..., min_length=2, description="Natural language question")],
    membership: Annotated[ProjectMember, Depends(require_project_membership)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """
    Natural language Q&A strictly grounded in this project's discussion memory,
    with meeting and timestamp citations.
    """
    engine = MemoryEngine(GeminiEmbeddingAdapter(), GeminiLLMAdapter())
    answer, citations = await engine.search_project_memory(
        project_id=project_id,
        query=q,
        db=db
    )
    return SearchAnswerResponse(
        query=q,
        answer=answer,
        citations=citations
    )
