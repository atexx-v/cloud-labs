"""Схеми запитів і відповідей API.

Окремо від моделей БД навмисно: модель описує, як дані лежать у таблиці,
а схема — що клієнт може надіслати і що отримає. Так клієнт не зможе,
наприклад, сам задати id чи created_at.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=100)


class UserOut(BaseModel):
    # from_attributes — дозволяє будувати схему прямо з об'єкта SQLAlchemy
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    name: str
    created_at: datetime


class PostCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    body: str = Field(min_length=1)
    author_id: int = Field(gt=0)


class PostOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    body: str
    author_id: int
    created_at: datetime
