def create_user(client, email="ann@example.com", name="Ann"):
    return client.post("/users", json={"email": email, "name": name})


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_create_and_get_user(client):
    r = create_user(client)
    assert r.status_code == 201
    user = r.json()
    assert user["email"] == "ann@example.com"

    r = client.get(f"/users/{user['id']}")
    assert r.status_code == 200
    assert r.json()["name"] == "Ann"


def test_duplicate_email_conflict(client):
    create_user(client)
    r = create_user(client, name="Ann again")
    assert r.status_code == 409


def test_invalid_email_rejected(client):
    r = client.post("/users", json={"email": "not-an-email", "name": "X"})
    assert r.status_code == 422


def test_missing_user_404(client):
    assert client.get("/users/9999").status_code == 404


def test_create_post_and_read(client):
    author = create_user(client).json()
    r = client.post(
        "/posts", json={"title": "Перший", "body": "Привіт", "author_id": author["id"]}
    )
    assert r.status_code == 201
    post = r.json()
    assert post["author_id"] == author["id"]

    assert client.get(f"/posts/{post['id']}").json()["title"] == "Перший"
    assert len(client.get("/posts").json()) == 1
    assert len(client.get(f"/users/{author['id']}/posts").json()) == 1


def test_post_unknown_author_404(client):
    r = client.post("/posts", json={"title": "T", "body": "B", "author_id": 9999})
    assert r.status_code == 404


def test_posts_newest_first_and_limit(client):
    author = create_user(client).json()
    for i in range(3):
        client.post("/posts", json={"title": f"P{i}", "body": "b", "author_id": author["id"]})
    posts = client.get("/posts?limit=2").json()
    assert [p["title"] for p in posts] == ["P2", "P1"]


def test_limit_above_max_rejected(client):
    assert client.get("/posts?limit=1000").status_code == 422


def test_delete_post(client):
    author = create_user(client).json()
    post = client.post(
        "/posts", json={"title": "T", "body": "B", "author_id": author["id"]}
    ).json()
    assert client.delete(f"/posts/{post['id']}").status_code == 204
    assert client.get(f"/posts/{post['id']}").status_code == 404
