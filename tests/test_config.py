import pytest
from pydantic import ValidationError
from sqlalchemy.engine import make_url

from app.config import Settings

# Аргументи конструктора мають пріоритет над змінними середовища,
# тому database_url=None «вимикає» DATABASE_URL, заданий у conftest.py


def test_url_from_parts_survives_special_chars():
    # Такі символи типові для паролів, які генерує AWS Secrets Manager
    password = "p@ss:w/rd#?%&"
    s = Settings(
        database_url=None,
        jwt_secret="x" * 32,
        db_host="db.example.com",
        db_user="blog",
        db_password=password,
        db_name="blog",
        db_sslmode="require",
    )
    url = make_url(s.sqlalchemy_url.render_as_string(hide_password=False))
    assert url.password == password
    assert url.host == "db.example.com"
    assert url.query["sslmode"] == "require"


def test_database_url_has_priority():
    s = Settings(database_url="postgresql://u:p@h/d", db_host="other", jwt_secret="x" * 32)
    assert s.sqlalchemy_url == "postgresql+psycopg://u:p@h/d"


def test_missing_connection_settings_fail_fast():
    with pytest.raises(ValidationError):
        Settings(database_url=None, jwt_secret="x" * 32, db_host="h", db_user="u", db_name="d")


def test_short_jwt_secret_rejected():
    with pytest.raises(ValidationError):
        Settings(database_url="postgresql://u:p@h/d", jwt_secret="short")
