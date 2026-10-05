from typing import Optional, Union

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings
from sqlalchemy.engine import URL


class Settings(BaseSettings):
    """Налаштування читаються зі змінних середовища, а не з коду.

    Так один і той самий образ працює і локально (compose), і в хмарі —
    змінюються лише змінні, які передає compose або Terraform.
    Пароль до бази ніколи не потрапляє в код чи образ.

    Два способи задати підключення:
    - DATABASE_URL — один рядок (зручно для compose);
    - DB_HOST, DB_USER, DB_PASSWORD, DB_NAME — окремо (так у хмарі: пароль
      ECS бере з AWS Secrets Manager і передає окремою змінною DB_PASSWORD).
    """

    database_url: Optional[str] = None

    # Ключ підпису JWT. У хмарі його генерує Terraform і кладе в Secrets Manager;
    # хто знає ключ — може випускати «справжні» токени, тому в коді його немає
    jwt_secret: str
    jwt_expires_minutes: int = 60

    db_host: Optional[str] = None
    db_port: int = 5432
    db_user: Optional[str] = None
    db_password: Optional[str] = None
    db_name: Optional[str] = None
    # prefer — шифрувати, якщо сервер підтримує (локальний Postgres — ні);
    # у хмарі Terraform ставить require: без TLS підключення буде відхилено
    db_sslmode: str = "prefer"

    @field_validator("database_url")
    @classmethod
    def use_psycopg3(cls, v: Optional[str]) -> Optional[str]:
        # SQLAlchemy для "postgresql://" за замовчуванням шукає драйвер psycopg2,
        # а в нас встановлений psycopg 3
        if v and v.startswith("postgresql://"):
            return v.replace("postgresql://", "postgresql+psycopg://", 1)
        return v

    @field_validator("jwt_secret")
    @classmethod
    def jwt_secret_long_enough(cls, v: str) -> str:
        # HS256 безпечний лише з довгим випадковим ключем
        if len(v) < 32:
            raise ValueError("JWT_SECRET має бути не коротшим за 32 символи")
        return v

    @model_validator(mode="after")
    def require_connection(self) -> "Settings":
        # Падаємо одразу при старті з зрозумілою помилкою, а не на першому запиті
        parts = (self.db_host, self.db_user, self.db_password, self.db_name)
        if not self.database_url and not all(parts):
            raise ValueError(
                "Задайте DATABASE_URL або DB_HOST, DB_USER, DB_PASSWORD, DB_NAME"
            )
        return self

    @property
    def sqlalchemy_url(self) -> Union[str, URL]:
        if self.database_url:
            return self.database_url
        # URL.create, а не f-рядок: пароль, який генерує AWS, містить символи
        # на кшталт @ : / #, і в склеєному рядку вони зламали б розбір адреси
        return URL.create(
            "postgresql+psycopg",
            username=self.db_user,
            password=self.db_password,
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            query={"sslmode": self.db_sslmode},
        )


settings = Settings()
