from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.config import settings

# Engine тримає пул з'єднань до бази — створюється один раз на процес.
# pool_pre_ping: перед видачею з'єднання з пулу перевіряє, чи воно живе.
# Керована база в хмарі (RDS) може обірвати неактивне з'єднання —
# без цього перший запит після паузи падав би з помилкою.
engine = create_engine(settings.sqlalchemy_url, pool_pre_ping=True)

# expire_on_commit=False — після commit об'єкт можна віддати у відповідь,
# не роблячи зайвий SELECT на кожне поле
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db():
    """Залежність FastAPI: одна сесія на один HTTP-запит.

    finally гарантує, що з'єднання повернеться в пул навіть при помилці.
    Стан між запитами не зберігається — тому застосунок stateless
    і його можна масштабувати горизонтально (лаба 2).
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
