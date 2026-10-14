FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 2. Окремий користувач без прав root: якщо в застосунку знайдеться вразливість,
#    зловмисник не отримає root усередині контейнера
RUN useradd --create-home --uid 10001 appuser

# 3. Код копіюємо останнім — він змінюється найчастіше
COPY alembic.ini docker-entrypoint.sh ./
COPY alembic ./alembic
COPY app ./app

USER appuser

EXPOSE 8000

# Перевірка стану для `docker ps` (у slim немає curl, тому через Python)
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

ENTRYPOINT ["sh", "docker-entrypoint.sh"]
