"""Authentication REST Endpoints."""

from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from backend.app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password
)
from backend.app.database import get_db
from backend.app.models.user import User
from backend.app.schemas.api import (
    AppleLoginRequest,
    TokenResponse,
    UserLoginRequest,
    UserResponse,
    UserSignupRequest
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def signup(request: UserSignupRequest, db: Annotated[AsyncSession, Depends(get_db)]):
    # Check if email exists
    stmt = select(User).where(User.email == request.email.lower().strip())
    existing = (await db.execute(stmt)).scalar_one_or_none()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email already exists"
        )

    user = User(
        email=request.email.lower().strip(),
        hashed_password=hash_password(request.password),
        full_name=request.full_name.strip()
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    access_token = create_access_token(user.id, {"email": user.email})
    refresh_token = create_refresh_token(user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user_id=user.id,
        email=user.email,
        full_name=user.full_name
    )


@router.post("/login", response_model=TokenResponse)
async def login(request: UserLoginRequest, db: Annotated[AsyncSession, Depends(get_db)]):
    stmt = select(User).where(User.email == request.email.lower().strip())
    user = (await db.execute(stmt)).scalar_one_or_none()

    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"}
        )

    access_token = create_access_token(user.id, {"email": user.email})
    refresh_token = create_refresh_token(user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user_id=user.id,
        email=user.email,
        full_name=user.full_name
    )


@router.post("/apple", response_model=TokenResponse)
async def apple_login(request: AppleLoginRequest, db: Annotated[AsyncSession, Depends(get_db)]):
    """Sign in with Apple handler."""
    stmt = select(User).where(User.apple_sub == request.apple_sub)
    user = (await db.execute(stmt)).scalar_one_or_none()

    if not user:
        # Check by email
        stmt2 = select(User).where(User.email == request.email.lower().strip())
        user = (await db.execute(stmt2)).scalar_one_or_none()
        if user:
            user.apple_sub = request.apple_sub
        else:
            user = User(
                email=request.email.lower().strip(),
                hashed_password=hash_password(f"apple_oauth_{request.apple_sub}"),
                full_name=request.full_name,
                apple_sub=request.apple_sub
            )
            db.add(user)
        await db.commit()
        await db.refresh(user)

    access_token = create_access_token(user.id, {"email": user.email})
    refresh_token = create_refresh_token(user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user_id=user.id,
        email=user.email,
        full_name=user.full_name
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(refresh_token: str, db: Annotated[AsyncSession, Depends(get_db)]):
    try:
        payload = decode_token(refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token type")
        user_id = payload.get("sub")
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    user = await db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")

    new_access = create_access_token(user.id, {"email": user.email})
    new_refresh = create_refresh_token(user.id)

    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
        user_id=user.id,
        email=user.email,
        full_name=user.full_name
    )
