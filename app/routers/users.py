from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Post, User
from app.schemas import PostOut, UserOut

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=List[UserOut])
def list_users(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    # Пагінація обов'язкова: без limit відповідь росте разом із таблицею
    stmt = select(User).order_by(User.id).limit(limit).offset(offset)
    return db.scalars(stmt).all()


@router.get("/{user_id}", response_model=UserOut)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="Користувача не знайдено")
    return user


@router.get("/{user_id}/posts", response_model=List[PostOut])
def list_user_posts(
    user_id: int,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    if db.get(User, user_id) is None:
        raise HTTPException(status_code=404, detail="Користувача не знайдено")
    stmt = (
        select(Post)
        .where(Post.author_id == user_id)
        .order_by(Post.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return db.scalars(stmt).all()
