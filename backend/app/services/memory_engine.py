"""Cross-Discussion Memory Engine.

Performs:
1. Vector embedding generation and storage scoped strictly per project.
2. Cross-meeting similarity retrieval and LLM relation judging:
   CONFIRMS | CONTRADICTS | UPDATES | RESOLVES_PREREQUISITE | NEW
3. Source verification and prerequisite dependency tracking (unblocking actions).
4. Personalized spoken-style briefing generator.
5. Natural language Q&A search with exact meeting and timestamp citations.
"""

import json
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple
import numpy as np
from pydantic import BaseModel, Field
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.adapters.base import BaseEmbeddingAdapter, BaseLLMAdapter
from backend.app.models.audit import AuditLog, Notification
from backend.app.models.extraction import Claim, Decision, Prerequisite
from backend.app.models.meeting import Meeting
from backend.app.models.memory import Link, MemoryEmbedding
from backend.app.schemas.api import CitationSource


class RelationJudgeResult(BaseModel):
    relation: str = Field(..., description="CONFIRMS | CONTRADICTS | UPDATES | RESOLVES_PREREQUISITE | NEW")
    short_reason: str = Field(..., description="Concise explanation of relationship")
    judge_confidence: float = Field(..., ge=0.0, le=1.0)


class MemoryEngine:
    """Manages cross-meeting memory, relation classification, briefings, and citations."""

    def __init__(self, embedding_adapter: BaseEmbeddingAdapter, llm_adapter: BaseLLMAdapter):
        self.embeddings = embedding_adapter
        self.llm = llm_adapter

    @staticmethod
    def cosine_similarity(v1: List[float], v2: List[float]) -> float:
        a = np.array(v1, dtype=np.float32)
        b = np.array(v2, dtype=np.float32)
        norm_a = np.linalg.norm(a)
        norm_b = np.linalg.norm(b)
        if norm_a == 0 or norm_b == 0:
            return 0.0
        return float(np.dot(a, b) / (norm_a * norm_b))

    async def link_meeting_items(
        self,
        project_id: str,
        meeting_id: str,
        db: AsyncSession,
        similarity_threshold: float = 0.70
    ) -> List[Link]:
        """
        Cross-examines newly extracted items from a meeting against prior items of the SAME project.
        Guaranteed: Never queries outside project_id.
        """
        # Fetch newly extracted items for this meeting
        new_claims = (await db.execute(select(Claim).where(Claim.meeting_id == meeting_id))).scalars().all()
        new_prereqs = (await db.execute(select(Prerequisite).where(Prerequisite.meeting_id == meeting_id))).scalars().all()
        new_decisions = (await db.execute(select(Decision).where(Decision.meeting_id == meeting_id))).scalars().all()

        new_items = []
        for c in new_claims:
            new_items.append((c.id, "claim", c.text))
        for p in new_prereqs:
            new_items.append((p.id, "prerequisite", p.text))
        for d in new_decisions:
            new_items.append((d.id, "decision", d.text))

        if not new_items:
            return []

        # Embed all new items
        new_texts = [item[2] for item in new_items]
        new_vectors = await self.embeddings.embed_texts(new_texts)

        # Fetch prior embeddings strictly scoped by project_id and NOT this meeting
        prior_embeddings_stmt = select(MemoryEmbedding).where(
            and_(
                MemoryEmbedding.project_id == project_id,
                ~MemoryEmbedding.item_id.in_([item[0] for item in new_items])
            )
        )
        prior_embeddings = (await db.execute(prior_embeddings_stmt)).scalars().all()

        created_links: List[Link] = []

        # Store new embeddings
        for (item_id, item_type, text), vec in zip(new_items, new_vectors):
            mem_emb = MemoryEmbedding(
                project_id=project_id,
                item_id=item_id,
                item_type=item_type,
                embedding_json=json.dumps(vec)
            )
            db.add(mem_emb)

        # Cross-examine each new item against prior items
        for (new_id, new_type, new_text), new_vec in zip(new_items, new_vectors):
            for prior in prior_embeddings:
                prior_vec = json.loads(prior.embedding_json)
                sim = self.cosine_similarity(new_vec, prior_vec)

                if sim >= similarity_threshold:
                    # Retrieve prior item text
                    prior_text = ""
                    if prior.item_type == "claim":
                        c = await db.get(Claim, prior.item_id)
                        if c:
                            prior_text = c.text
                    elif prior.item_type == "prerequisite":
                        p = await db.get(Prerequisite, prior.item_id)
                        if p:
                            prior_text = p.text
                    elif prior.item_type == "decision":
                        d = await db.get(Decision, prior.item_id)
                        if d:
                            prior_text = d.text

                    if not prior_text:
                        continue

                    # Judge relationship with LLM
                    prompt = (
                        f"Analyze the relationship between two project items from different meetings.\n\n"
                        f"PRIOR ITEM ({prior.item_type}): \"{prior_text}\"\n"
                        f"NEW ITEM ({new_type}): \"{new_text}\"\n\n"
                        "Classify their relationship into EXACTLY one of these categories:\n"
                        "- CONFIRMS: New item validates, reinforces, or proves the prior item.\n"
                        "- CONTRADICTS: New item challenges, disproves, or disagrees with prior item.\n"
                        "- UPDATES: New item replaces, modifies, or refines prior item with new information.\n"
                        "- RESOLVES_PREREQUISITE: New item marks a prior requirement or dependency as resolved/completed.\n"
                        "- NEW: Unrelated or novel topic.\n\n"
                        "Respond ONLY with a JSON object: { 'relation': str, 'short_reason': str, 'judge_confidence': float }"
                    )

                    try:
                        judge: RelationJudgeResult = await self.llm.generate_structured(
                            prompt=prompt,
                            response_schema=RelationJudgeResult,
                            system_prompt="You are a strict project memory consistency judge.",
                            temperature=0.0
                        )

                        if judge.relation != "NEW":
                            needs_review = (judge.relation == "CONTRADICTS" and judge.judge_confidence < 0.80)

                            link = Link(
                                project_id=project_id,
                                old_item_id=prior.item_id,
                                old_item_type=prior.item_type,
                                new_item_id=new_id,
                                new_item_type=new_type,
                                relation=judge.relation,
                                short_reason=judge.short_reason,
                                similarity=round(sim, 4),
                                judge_confidence=round(judge.judge_confidence, 4),
                                needs_review=needs_review
                            )
                            db.add(link)
                            created_links.append(link)

                            # Handle prerequisite resolution unblocking
                            if judge.relation == "RESOLVES_PREREQUISITE" and prior.item_type == "prerequisite":
                                prior_prereq = await db.get(Prerequisite, prior.item_id)
                                if prior_prereq and prior_prereq.status != "done":
                                    prior_prereq.status = "done"
                                    # Audit log
                                    audit = AuditLog(
                                        project_id=project_id,
                                        entity_type="prerequisite",
                                        entity_id=prior_prereq.id,
                                        actor_user_id="system_memory_engine",
                                        action="resolve",
                                        old_state_json="open",
                                        new_state_json="done",
                                        reason=f"Resolved by meeting item {new_id}: {judge.short_reason}"
                                    )
                                    db.add(audit)

                            # If contradiction found, notify project
                            if judge.relation == "CONTRADICTS":
                                notif = Notification(
                                    user_id="project_broadcast",
                                    project_id=project_id,
                                    title="Contradiction Detected in Discussion Memory",
                                    message=f"A new statement contradicts an earlier item: {judge.short_reason}",
                                    type="contradiction_found"
                                )
                                db.add(notif)
                    except Exception:
                        continue

        await db.commit()
        return created_links

    async def generate_user_brief(
        self,
        project_id: str,
        user_id: str,
        user_name: str,
        db: AsyncSession
    ) -> Dict:
        """
        Generates a 60-90 second spoken-style briefing script tailored for the user.
        Summarizes: latest decisions, pending prerequisites, contradicted/unverified claims,
        and tasks assigned directly to this user.
        """
        # Fetch latest decisions
        decisions = (await db.execute(
            select(Decision).where(Decision.project_id == project_id).order_by(Decision.created_at.desc()).limit(5)
        )).scalars().all()

        # Fetch open prerequisites
        prereqs = (await db.execute(
            select(Prerequisite).where(
                and_(Prerequisite.project_id == project_id, Prerequisite.status == "open")
            ).limit(5)
        )).scalars().all()

        # Fetch contradictions needing review
        contradictions = (await db.execute(
            select(Link).where(
                and_(Link.project_id == project_id, Link.relation == "CONTRADICTS")
            ).limit(3)
        )).scalars().all()

        # Fetch user's assigned items
        my_tasks = (await db.execute(
            select(Prerequisite).where(
                and_(Prerequisite.project_id == project_id, Prerequisite.owner_user_id == user_id, Prerequisite.status == "open")
            )
        )).scalars().all()

        prompt = (
            f"You are the executive briefing assistant for EASE. Generate a crisp, professional, "
            f"spoken-style pre-meeting audio brief (60-90 seconds when read aloud) for {user_name}.\n\n"
            f"LATEST DECISIONS ({len(decisions)}):\n" + "\n".join(f"- {d.text}" for d in decisions) + "\n\n"
            f"PENDING PREREQUISITES & BLOCKERS ({len(prereqs)}):\n" + "\n".join(f"- {p.text} (Depends on: {p.depends_on})" for p in prereqs) + "\n\n"
            f"CONTRADICTIONS OR UNVERIFIED CLAIMS ({len(contradictions)}):\n" + "\n".join(f"- {c.short_reason}" for c in contradictions) + "\n\n"
            f"TASKS ASSIGNED SPECIFICALLY TO {user_name.upper()} ({len(my_tasks)}):\n" + "\n".join(f"- {t.text}" for t in my_tasks) + "\n\n"
            "Format the response directly as the spoken speech script. Do not write 'Here is your brief' or stage directions."
        )

        script = await self.llm.generate_text(
            prompt=prompt,
            system_prompt="You speak with executive clarity, conciseness, and natural cadence.",
            temperature=0.3
        )

        return {
            "project_id": project_id,
            "user_id": user_id,
            "spoken_script": script,
            "latest_decisions_count": len(decisions),
            "pending_prerequisites_count": len(prereqs),
            "assigned_tasks_count": len(my_tasks),
            "generated_at": datetime.now(timezone.utc)
        }

    async def search_project_memory(
        self,
        project_id: str,
        query: str,
        db: AsyncSession,
        top_k: int = 5
    ) -> Tuple[str, List[CitationSource]]:
        """
        Natural-language question answering over stored project memory.
        Answers ONLY from stored data and includes exact meeting + timestamp citations.
        """
        query_vector = await self.embeddings.embed_query(query)

        # Fetch embeddings strictly for this project
        stmt = select(MemoryEmbedding).where(MemoryEmbedding.project_id == project_id)
        embeddings = (await db.execute(stmt)).scalars().all()

        if not embeddings:
            return "No historical project discussions or memory items are recorded for this project yet.", []

        scored = []
        for mem in embeddings:
            vec = json.loads(mem.embedding_json)
            sim = self.cosine_similarity(query_vector, vec)
            scored.append((sim, mem))

        scored.sort(key=lambda x: x[0], reverse=True)
        top_matches = scored[:top_k]

        citations: List[CitationSource] = []
        evidence_lines = []

        for sim, mem in top_matches:
            item_text = ""
            meeting_id = ""
            start_ms = 0
            end_ms = 0

            if mem.item_type == "claim":
                c = await db.get(Claim, mem.item_id)
                if c:
                    item_text = c.text
                    meeting_id = c.meeting_id
                    start_ms = c.timestamp_start_ms
                    end_ms = c.timestamp_end_ms
            elif mem.item_type == "decision":
                d = await db.get(Decision, mem.item_id)
                if d:
                    item_text = d.text
                    meeting_id = d.meeting_id
                    start_ms = d.timestamp_start_ms
                    end_ms = d.timestamp_end_ms
            elif mem.item_type == "prerequisite":
                p = await db.get(Prerequisite, mem.item_id)
                if p:
                    item_text = p.text
                    meeting_id = p.meeting_id
                    start_ms = p.timestamp_start_ms
                    end_ms = p.timestamp_end_ms

            if item_text and meeting_id:
                m = await db.get(Meeting, meeting_id)
                m_title = m.title if m else "Meeting"
                citations.append(
                    CitationSource(
                        meeting_id=meeting_id,
                        meeting_title=m_title,
                        timestamp_start_ms=start_ms,
                        timestamp_end_ms=end_ms,
                        quote=item_text
                    )
                )
                evidence_lines.append(f"[{m_title} @ {start_ms}ms-{end_ms}ms]: \"{item_text}\"")

        prompt = (
            f"You are the memory search engine for EASE. Answer the following user question strictly using ONLY the provided project memory citations:\n\n"
            f"QUESTION: {query}\n\n"
            f"STORED PROJECT MEMORY CITATIONS:\n" + "\n".join(evidence_lines) + "\n\n"
            "CRITICAL INSTRUCTIONS:\n"
            "- Answer ONLY based on the facts provided in the citations above.\n"
            "- Do not extrapolate or assume unmentioned details.\n"
            "- Cite the source meeting and timestamp for each statement you make."
        )

        answer = await self.llm.generate_text(
            prompt=prompt,
            system_prompt="You are an uncompromising, truthful project intelligence search assistant.",
            temperature=0.1
        )

        return answer, citations
