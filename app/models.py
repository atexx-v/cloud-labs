from datetime import datetime
from typing import List

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    """Таблиця 1: користувачі (автори постів)."""

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    # unique — унікальність гарантує сама база, а не перевірка в коді:
    # два одночасні запити з однаковим email не створять дубль
    email: Mapped[str] = mapped_column(String(255), unique=True)
    name: Mapped[str] = mapped_column(String(100))
    # server_default — час ставить база, а не застосунок
    # (годинники різних екземплярів можуть розходитись)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    posts: Mapped[List["Post"]] = relationship(back_populates="author")


class Post(Base):
    """Таблиця 2: пости, кожен належить користувачу."""

    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text)
    # Зовнішній ключ: пост не може посилатись на неіснуючого автора.
    # ondelete=CASCADE — при видаленні користувача база сама видалить його пости.
    # index=True — пошук постів автора не перебиратиме всю таблицю.
    author_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    author: Mapped[User] = relationship(back_populates="posts")
