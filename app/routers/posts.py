from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import TypeAdapter
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import cache
from app.config import settings
from app.db import get_db
from app.models import Post, User
from app.schemas import PostCreate, PostOut

router = APIRouter(prefix="/posts", tags=["posts"])

posts_adapter = TypeAdapter(List[PostOut])

@router.post("", response_model=PostOut, status_code=201)
def create_post(data: PostCreate, db: Session = Depends(get_db)):
    if db.get(User, data.author_id) is None:
        raise HTTPException(status_code=404, detail="Автора з таким author_id немає")

    post = Post(title=data.title, body=data.body, author_id=data.author_id)
    db.add(post)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=404, detail="Автора з таким author_id немає")
    db.refresh(post)
    return post

@router.get("", response_model=List[PostOut])
def list_posts(
    request: Request,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    key = f"posts:list:{limit}:{offset}"
    bypass = "no-cache" in request.headers.get("cache-control", "")

    if not bypass:
        cached = cache.get(key)
        if cached is not None:
            return Response(content=cached, media_type="application/json", headers={"X-Cache": "HIT"})

    stmt = select(Post).order_by(Post.id.desc()).limit(limit).offset(offset)
    posts = db.scalars(stmt).all()
    body = posts_adapter.dump_json(posts_adapter.validate_python(posts, from_attributes=True))

    if bypass:
        return Response(content=body, media_type="application/json", headers={"X-Cache": "BYPASS"})

    cache.set(key, body, settings.cache_ttl_seconds)
    return Response(content=body, media_type="application/json", headers={"X-Cache": "MISS"})

@router.get("/{post_id}", response_model=PostOut)
def get_post(post_id: int, db: Session = Depends(get_db)):
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Пост не знайдено")
    return post

@router.delete("/{post_id}", status_code=204)
def delete_post(post_id: int, db: Session = Depends(get_db)):
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Пост не знайдено")
    db.delete(post)
    db.commit()
    return Response(status_code=204)
