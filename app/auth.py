import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import User
from app.security import decode_access_token

# auto_error=False: за відсутності заголовка HTTPBearer сам повернув би 403,
# а правильний код для «не автентифікований» — 401. Тому помилку кидаємо самі.
# Схема також додає кнопку Authorize у Swagger UI.
bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    unauthorized = HTTPException(
        status_code=401,
        detail="Потрібна автентифікація",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise unauthorized
    try:
        user_id = decode_access_token(credentials.credentials)
    except (jwt.PyJWTError, ValueError):
        # Підроблений, прострочений або пошкоджений токен — для клієнта все одно 401
        raise unauthorized
    user = db.get(User, user_id)
    if user is None:  # користувача видалили після видачі токена
        raise unauthorized
    return user
