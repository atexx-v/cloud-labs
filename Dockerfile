# Базовий образ із зафіксованою версією (не latest):
# 3.12 — версія Python, slim — Debian без зайвих пакетів (~150 MB замість ~1 GB),
# bookworm — конкретний випуск Debian 12, щоб ОС не змінилась при наступній збірці
FROM python:3.12-slim-bookworm

# Не писати .pyc-файли (в контейнері вони марні) і не буферизувати stdout —
# інакше логи з'являлись би в docker logs / CloudWatch із затримкою
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 1. Спочатку лише список залежностей і їх встановлення — окремий шар.
#    Поки requirements.txt не змінився, Docker бере цей шар із кешу,
#    і зміна коду не запускає pip install заново.
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

# Документація: застосунок слухає порт 8000
EXPOSE 8000

# Перевірка стану для `docker ps` (у slim немає curl, тому через Python)
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

ENTRYPOINT ["sh", "docker-entrypoint.sh"]
