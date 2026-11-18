from typing import Optional

import redis

from app.config import settings

client = (
    redis.Redis.from_url(
        settings.redis_url,
        socket_connect_timeout=0.5,
        socket_timeout=0.5,
    )
    if settings.redis_url
    else None
)

def get(key: str) -> Optional[bytes]:
    if client is None:
        return None
    try:
        return client.get(key)
    except redis.RedisError:
        return None

def set(key: str, value: bytes, ttl: int) -> None:
    if client is None:
        return
    try:
        client.set(key, value, ex=ttl)
    except redis.RedisError:
        pass
