"""Налаштування Alembic — інструменту міграцій схеми БД.

Міграція — це версійований скрипт зміни схеми (як коміт у git, але для таблиць).
Контейнер при старті виконує `alembic upgrade head` і доводить базу до
актуальної версії — однаково і для локального Postgres, і для RDS у хмарі.
"""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine

from app.config import settings
from app.models import Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Метадані моделей — щоб `alembic revision --autogenerate` міг порівняти
# моделі з реальною базою і згенерувати різницю
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Режим без підключення: лише друкує SQL (alembic upgrade head --sql)."""
    context.configure(url=settings.sqlalchemy_url, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    # Engine створюємо напряму, а не через alembic.ini:
    # configparser зламався б на символі % у паролі
    engine = create_engine(settings.sqlalchemy_url)
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
