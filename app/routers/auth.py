from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.db import get_db
from app.models import User
from app.schemas import LoginIn, Token, UserOut, UserRegister
from app.security import DUMMY_HASH, create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserOut, status_code=201)
def register(data: UserRegister, db: Session = Depends(get_db)):
    user = User(email=data.email, name=data.name, password_hash=hash_password(data.password))
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        # Єдине обмеження, яке тут можна порушити, — унікальний email
        db.rollback()
        raise HTTPException(status_code=409, detail="Користувач з таким email уже існує")
    db.refresh(user)
    return user


@router.post("/login", response_model=Token)
def login(data: LoginIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == data.email))
    # Однакова відповідь і для «немає такого email», і для «невірний пароль»:
    # не підказуємо стороннім, які email-и зареєстровані
    stored = user.password_hash if user and user.password_hash else DUMMY_HASH
    ok = verify_password(data.password, stored)
    if user is None or not user.password_hash or not ok:
        raise HTTPException(
            status_code=401,
            detail="Невірний email або пароль",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return Token(access_token=create_access_token(user.id))


@router.get("/me", response_model=UserOut)
def me(current: User = Depends(get_current_user)):
    return current
