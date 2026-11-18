import json
import math
import os
import random
import uuid
from collections import Counter

from locust import HttpUser, LoadTestShape, SequentialTaskSet, between, events, task

USERS = int(os.getenv("LT_USERS", "60"))
RAMP_UP = int(os.getenv("LT_RAMP_UP", "120"))
HOLD = int(os.getenv("LT_HOLD", "300"))
RAMP_DOWN = int(os.getenv("LT_RAMP_DOWN", "180"))
NO_CACHE = os.getenv("LT_NO_CACHE") == "1"
RESULTS_DIR = os.path.join(os.path.dirname(__file__), "results")

cache_stats = Counter()


class ReadHeavyFlow(SequentialTaskSet):
    def on_start(self):
        self.headers = {"Cache-Control": "no-cache"} if NO_CACHE else {}
        email = f"{uuid.uuid4().hex}@loadtest.example.com"
        response = self.client.post("/users", json={"email": email, "name": "Load"}, name="POST /users")
        self.author_id = response.json()["id"] if response.status_code == 201 else None
        self.post_id = None
        self.recent_ids = []

    def ensure_author(self):
        if self.author_id is None:
            email = f"{uuid.uuid4().hex}@loadtest.example.com"
            response = self.client.post("/users", json={"email": email, "name": "Load"}, name="POST /users")
            if response.status_code == 201:
                self.author_id = response.json()["id"]
        return self.author_id is not None

    def list_posts(self, offset=0):
        with self.client.get(
            f"/posts?limit=20&offset={offset}",
            headers=self.headers,
            name="GET /posts",
            catch_response=True,
        ) as response:
            cache_stats[response.headers.get("X-Cache", "NONE")] += 1
            if response.status_code == 200:
                self.recent_ids = [post["id"] for post in response.json()]
            else:
                response.failure(str(response.status_code))

    @task
    def create_post(self):
        if not self.ensure_author():
            return
        response = self.client.post(
            "/posts",
            json={"title": "Load test", "body": "x" * 200, "author_id": self.author_id},
            name="POST /posts",
        )
        if response.status_code == 201:
            self.post_id = response.json()["id"]

    @task
    def read_list_1(self):
        self.list_posts()

    @task
    def read_new_post(self):
        if self.post_id is not None:
            self.client.get(f"/posts/{self.post_id}", name="GET /posts/{id}")

    @task
    def read_list_2(self):
        self.list_posts()

    @task
    def read_author(self):
        if self.author_id is not None:
            self.client.get(f"/users/{self.author_id}", name="GET /users/{id}")

    @task
    def read_list_3(self):
        self.list_posts()

    @task
    def read_random_post(self):
        post_id = random.choice(self.recent_ids) if self.recent_ids else self.post_id
        if post_id is not None:
            self.client.get(f"/posts/{post_id}", name="GET /posts/{id}")

    @task
    def read_author_posts(self):
        if self.author_id is not None:
            self.client.get(f"/users/{self.author_id}/posts", name="GET /users/{id}/posts")

    @task
    def read_list_4(self):
        self.list_posts()

    @task
    def read_list_page_2(self):
        self.list_posts(offset=20)


class Visitor(HttpUser):
    wait_time = between(0.2, 0.6)
    tasks = [ReadHeavyFlow]


class ThreePhaseProfile(LoadTestShape):
    def tick(self):
        t = self.get_run_time()
        if t < RAMP_UP:
            users = math.ceil(USERS * t / RAMP_UP)
        elif t < RAMP_UP + HOLD:
            users = USERS
        elif t < RAMP_UP + HOLD + RAMP_DOWN:
            users = math.ceil(USERS * (RAMP_UP + HOLD + RAMP_DOWN - t) / RAMP_DOWN)
        else:
            return None
        return max(users, 1), USERS


@events.quitting.add_listener
def save_cache_stats(environment, **kwargs):
    os.makedirs(RESULTS_DIR, exist_ok=True)
    tag = os.getenv("LT_TAG", "run")
    with open(os.path.join(RESULTS_DIR, f"{tag}_cache.json"), "w") as f:
        json.dump(dict(cache_stats), f)
