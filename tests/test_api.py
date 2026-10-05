def register(client, email="ann@example.com", name="Ann", password="correct-horse"):
    return client.post("/auth/register", json={"email": email, "name": name, "password": password})


def login_headers(client, email="ann@example.com", password="correct-horse"):
    token = client.post("/auth/login", json={"email": email, "password": password}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def make_post(client, headers, title="Перший", body="Привіт"):
    return client.post("/posts", json={"title": title, "body": body}, headers=headers)


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_register_and_get_user(client):
    r = register(client)
    assert r.status_code == 201
    user = r.json()
    assert user["email"] == "ann@example.com"
    assert "password" not in user and "password_hash" not in user  # хеш не віддається

    r = client.get(f"/users/{user['id']}")
    assert r.status_code == 200
    assert r.json()["name"] == "Ann"


def test_duplicate_email_conflict(client):
    register(client)
    assert register(client, name="Ann again").status_code == 409


def test_invalid_email_rejected(client):
    assert register(client, email="not-an-email").status_code == 422


def test_short_password_rejected(client):
    assert register(client, password="short").status_code == 422


def test_missing_user_404(client):
    assert client.get("/users/9999").status_code == 404


# --- автентифікація (бонус 6) ---

def test_login_returns_token(client):
    register(client)
    r = client.post("/auth/login", json={"email": "ann@example.com", "password": "correct-horse"})
    assert r.status_code == 200
    assert r.json()["token_type"] == "bearer"
    assert r.json()["access_token"]


def test_login_wrong_password_401(client):
    register(client)
    r = client.post("/auth/login", json={"email": "ann@example.com", "password": "wrong-password"})
    assert r.status_code == 401


def test_login_unknown_email_same_401(client):
    # та сама відповідь, що й для невірного пароля — не видаємо, які email-и існують
    r = client.post("/auth/login", json={"email": "nobody@example.com", "password": "whatever123"})
    assert r.status_code == 401
    assert r.json()["detail"] == "Невірний email або пароль"


def test_create_post_without_token_401(client):
    r = client.post("/posts", json={"title": "T", "body": "B"})
    assert r.status_code == 401
    assert r.headers["www-authenticate"] == "Bearer"


def test_delete_without_token_401(client):
    assert client.delete("/posts/1").status_code == 401


def test_garbage_token_401(client):
    r = client.post("/posts", json={"title": "T", "body": "B"}, headers={"Authorization": "Bearer abc.def.ghi"})
    assert r.status_code == 401


def test_forged_token_401(client):
    import jwt

    register(client)
    forged = jwt.encode({"sub": "1", "exp": 9999999999}, "x" * 40, algorithm="HS256")
    r = client.post("/posts", json={"title": "T", "body": "B"}, headers={"Authorization": f"Bearer {forged}"})
    assert r.status_code == 401


def test_expired_token_401(client):
    import time

    import jwt

    from app.config import settings

    register(client)
    expired = jwt.encode({"sub": "1", "iat": 1, "exp": int(time.time()) - 10}, settings.jwt_secret, algorithm="HS256")
    r = client.post("/posts", json={"title": "T", "body": "B"}, headers={"Authorization": f"Bearer {expired}"})
    assert r.status_code == 401


def test_me_returns_current_user(client):
    register(client)
    r = client.get("/auth/me", headers=login_headers(client))
    assert r.status_code == 200
    assert r.json()["email"] == "ann@example.com"


# --- пости ---

def test_create_post_with_token_uses_token_author(client):
    author = register(client).json()
    r = make_post(client, login_headers(client))
    assert r.status_code == 201
    post = r.json()
    assert post["author_id"] == author["id"]

    assert client.get(f"/posts/{post['id']}").json()["title"] == "Перший"  # читання публічне
    assert len(client.get("/posts").json()) == 1
    assert len(client.get(f"/users/{author['id']}/posts").json()) == 1


def test_author_cannot_be_spoofed(client):
    register(client)
    register(client, email="bob@example.com", name="Bob")
    ann = login_headers(client)
    r = client.post("/posts", json={"title": "T", "body": "B", "author_id": 2}, headers=ann)
    assert r.status_code == 201
    assert r.json()["author_id"] == 1  # поле author_id у запиті ігнорується


def test_posts_newest_first_and_limit(client):
    register(client)
    h = login_headers(client)
    for i in range(3):
        make_post(client, h, title=f"P{i}")
    posts = client.get("/posts?limit=2").json()
    assert [p["title"] for p in posts] == ["P2", "P1"]


def test_limit_above_max_rejected(client):
    assert client.get("/posts?limit=1000").status_code == 422


def test_delete_own_post(client):
    register(client)
    h = login_headers(client)
    post = make_post(client, h).json()
    assert client.delete(f"/posts/{post['id']}", headers=h).status_code == 204
    assert client.get(f"/posts/{post['id']}").status_code == 404


def test_delete_foreign_post_403(client):
    register(client)
    register(client, email="bob@example.com", name="Bob")
    post = make_post(client, login_headers(client)).json()
    bob = login_headers(client, email="bob@example.com")
    assert client.delete(f"/posts/{post['id']}", headers=bob).status_code == 403
