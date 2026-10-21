import socket

from fastapi import FastAPI
from fastapi.responses import RedirectResponse

from app.routers import posts, users

app = FastAPI(
    title="Mini Blog API",
    version="1.0.0",
    description="REST API для лабораторних з хмарних технологій: користувачі та їхні пости.",
)

app.include_router(users.router)
app.include_router(posts.router)

INSTANCE = socket.gethostname()

@app.get("/health", tags=["service"])
def health():
    return {"status": "ok", "instance": INSTANCE, "version": "1.0"}

@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")
