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

# Ім'я хоста контейнера — у кожного екземпляра своє.
# Видно, який саме екземпляр відповів (зручно показувати балансувальник і автоскейл)
INSTANCE = socket.gethostname()


@app.get("/health", tags=["service"])
def health():
    """Health check для балансувальника.

    Навмисно не ходить у базу: якщо база тимчасово недоступна, балансувальник
    вважав би нездоровими ВСІ екземпляри і почав би їх перезапускати —
    це не допомогло б, а лише додало б простою.
    """
    return {"status": "ok", "instance": INSTANCE}


@app.get("/", include_in_schema=False)
def root():
    # Swagger UI FastAPI генерує сам за адресою /docs (бонусне завдання 8 лаби 1)
    return RedirectResponse(url="/docs")
