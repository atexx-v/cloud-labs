from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.db import get_db
from app.models import Post, User
from app.schemas import PostCreate, PostOut

router = APIRouter(prefix="/posts", tags=["posts"])


@router.post("", response_model=PostOut, status_code=201)
def create_post(
    data: PostCreate,
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),  # без дійсного токена тут буде 401
):
    post = Post(title=data.title, body=data.body, author_id=current.id)
    db.add(post)
    db.commit()
    db.refresh(post)
    return post


@router.get("", response_model=List[PostOut])
def list_posts(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    # Найновіші першими. Це найнавантаженіший ендпоінт —
    # саме його в лабі 2 переводимо на кеш
    stmt = select(Post).order_by(Post.id.desc()).limit(limit).offset(offset)
    return db.scalars(stmt).all()


@router.get("/{post_id}", response_model=PostOut)
def get_post(post_id: int, db: Session = Depends(get_db)):
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Пост не знайдено")
    return post


@router.delete("/{post_id}", status_code=204)
def delete_post(
    post_id: int,
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Пост не знайдено")
    # 403, а не 401: користувач автентифікований, але чужий пост видаляти не може
    if post.author_id != current.id:
        raise HTTPException(status_code=403, detail="Можна видаляти лише власні пости")
    db.delete(post)
    db.commit()
    return Response(status_code=204)
