"""Паролі та JWT-токени.

Пароль у базі зберігається не як текст, а як хеш: навіть той, хто прочитає базу,
не дізнається паролі користувачів. Токен — це підписаний «пропуск»: сервер видає його
після входу, а далі лише перевіряє підпис і не звертається до сховища сесій.
Тому застосунок залишається stateless і масштабується горизонтально (лаба 2).
"""

import hashlib
import hmac
import os
import time

import jwt

from app.config import settings

ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    # scrypt — повільний за задумом, щоб підбір паролів був дорогим; вбудований в Python,
    # окремої бібліотеки (і збірки під ARM) не потрібно. Сіль — випадкова для кожного
    # пароля, тому однакові паролі мають різні хеші.
    salt = os.urandom(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1, dklen=32)
    return f"scrypt${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        _, salt_hex, digest_hex = stored.split("$")
        salt = bytes.fromhex(salt_hex)
        expected = bytes.fromhex(digest_hex)
    except ValueError:
        return False
    actual = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1, dklen=32)
    # compare_digest порівнює за сталий час — відповідь не виказує, скільки символів збіглось
    return hmac.compare_digest(actual, expected)


# Хеш-пустушка: щоб вхід неіснуючого користувача займав стільки ж часу, скільки вхід
# існуючого з невірним паролем — інакше за часом відповіді можна перебирати email-и
DUMMY_HASH = hash_password("dummy-password")


def create_access_token(user_id: int) -> str:
    now = int(time.time())
    payload = {
        "sub": str(user_id),  # кому видано токен
        "iat": now,
        "exp": now + settings.jwt_expires_minutes * 60,  # після цього токен не діє
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def decode_access_token(token: str) -> int:
    """Перевіряє підпис і термін дії. Кидає jwt.PyJWTError, якщо токен недійсний."""
    payload = jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=[ALGORITHM],  # явно вказуємо алгоритм — захист від підміни на "none"
        options={"require": ["exp", "sub"]},
    )
    return int(payload["sub"])
