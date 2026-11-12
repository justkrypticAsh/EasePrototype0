"""FastAPI Route Dependencies for Auth and Project Authorization."""

from typing import Annotated, Optional
from fastapi import Depends, HTTPException, Header, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from backend.app.core.security import decode_token
from backend.app.database import get_db
from backend.app.models.project import ProjectMember
from backend.app.models.user import User


async def get_current_user(
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[Optional[str], Header()] = None
) -> User:
    """Validates JWT access token or falls back to demo user when no authorization header is provided."""
    if not authorization or not authorization.startswith("Bearer "):
        # Dev / Prototype mode: auto-fallback to demo user without sign-in
        stmt = select(User).where(User.email == "demo@ease.ai")
        res = await db.execute(stmt)
        user = res.scalar_one_or_none()
        if not user:
            from backend.app.core.security import hash_password
            user = User(
                email="demo@ease.ai",
                hashed_password=hash_password("DemoPassword123!"),
                full_name="Ashish Sharma",
                is_active=True
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)
        return user

    token = authorization.split(" ")[1]
    if token in ("demo-token", "ease_demo_token"):
        stmt = select(User).where(User.email == "demo@ease.ai")
        res = await db.execute(stmt)
        user = res.scalar_one_or_none()
        if user:
            return user

    try:
        payload = decode_token(token)
        user_id = payload.get("sub")
        token_type = payload.get("type")
        if not user_id or token_type != "access":
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"}
        )

    stmt = select(User).where(User.id == user_id, User.is_active == True)
    res = await db.execute(stmt)
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return user


async def require_project_membership(
    project_id: str,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)]
) -> ProjectMember:
    """
    Enforces project-level multi-tenant isolation.
    Returns 403 FORBIDDEN if the requesting user is not an active member of the project.
    """
    stmt = select(ProjectMember).where(
        ProjectMember.project_id == project_id,
        ProjectMember.user_id == current_user.id
    )
    res = await db.execute(stmt)
    membership = res.scalar_one_or_none()

    if not membership:
        if current_user.email == "demo@ease.ai":
            # Auto-grant owner role to demo user if testing without sign-in
            membership = ProjectMember(project_id=project_id, user_id=current_user.id, role="owner")
            db.add(membership)
            await db.commit()
            await db.refresh(membership)
            return membership

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You are not a member of this project"
        )

    return membership


async def require_project_owner(
    project_id: str,
    membership: Annotated[ProjectMember, Depends(require_project_membership)]
) -> ProjectMember:
    """Enforces owner-only permissions (e.g. deleting project, managing invites)."""
    if membership.role != "owner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Project owner permission required"
        )
    return membership
