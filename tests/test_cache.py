import fakeredis
import pytest

from app import cache

@pytest.fixture()
def redis_client(monkeypatch):
    fake = fakeredis.FakeRedis()
    monkeypatch.setattr(cache, "client", fake)
    return fake

def seed(client):
    user = client.post("/users", json={"email": "ann@example.com", "name": "Ann"}).json()
    client.post("/posts", json={"title": "First", "body": "Body", "author_id": user["id"]})
    return user

def test_without_redis_list_still_works(client):
    seed(client)
    r = client.get("/posts")
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert r.headers["X-Cache"] == "MISS"

def test_second_read_is_served_from_cache(client, redis_client):
    seed(client)
    first = client.get("/posts")
    second = client.get("/posts")
    assert first.headers["X-Cache"] == "MISS"
    assert second.headers["X-Cache"] == "HIT"
    assert first.json() == second.json()

def test_entry_has_ttl(client, redis_client):
    seed(client)
    client.get("/posts?limit=5&offset=0")
    ttl = redis_client.ttl("posts:list:5:0")
    assert 0 < ttl <= 30

def test_cached_list_is_stale_until_ttl_expires(client, redis_client):
    user = seed(client)
    client.get("/posts")
    client.post("/posts", json={"title": "Second", "body": "Body", "author_id": user["id"]})
    assert len(client.get("/posts").json()) == 1
    redis_client.flushall()
    assert len(client.get("/posts").json()) == 2

def test_no_cache_header_bypasses_cache(client, redis_client):
    seed(client)
    client.get("/posts")
    r = client.get("/posts", headers={"Cache-Control": "no-cache"})
    assert r.headers["X-Cache"] == "BYPASS"

def test_different_pages_use_different_keys(client, redis_client):
    seed(client)
    client.get("/posts?limit=20&offset=0")
    r = client.get("/posts?limit=20&offset=20")
    assert r.headers["X-Cache"] == "MISS"
    assert r.json() == []

def test_redis_failure_falls_back_to_database(client, monkeypatch):
    import redis

    class Broken:
        def get(self, key):
            raise redis.ConnectionError()

        def set(self, key, value, ex=None):
            raise redis.ConnectionError()

    monkeypatch.setattr(cache, "client", Broken())
    seed(client)
    r = client.get("/posts")
    assert r.status_code == 200
    assert len(r.json()) == 1
