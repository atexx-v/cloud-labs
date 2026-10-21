from typing import Optional, Union

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings
from sqlalchemy.engine import URL

class Settings(BaseSettings):

    database_url: Optional[str] = None

    db_host: Optional[str] = None
    db_port: int = 5432
    db_user: Optional[str] = None
    db_password: Optional[str] = None
    db_name: Optional[str] = None
    db_sslmode: str = "prefer"

    @field_validator("database_url")
    @classmethod
    def use_psycopg3(cls, v: Optional[str]) -> Optional[str]:
        if v and v.startswith("postgresql://"):
            return v.replace("postgresql://", "postgresql+psycopg://", 1)
        return v

    @model_validator(mode="after")
    def require_connection(self) -> "Settings":
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
