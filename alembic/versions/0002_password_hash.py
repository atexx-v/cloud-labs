"""Автентифікація: хеш пароля користувача

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-05
"""
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # nullable: у базі в хмарі вже є користувачі без паролів — вони просто не зможуть увійти
    op.add_column("users", sa.Column("password_hash", sa.String(255), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "password_hash")
