#!/bin/sh
# set -e: якщо міграція впала — контейнер завершується з помилкою,
# а не запускає сервер поверх бази зі старою схемою
set -e

alembic upgrade head

# exec замінює процес shell на uvicorn — uvicorn стає PID 1 і сам отримує
# SIGTERM при зупинці контейнера. Без exec сигнал отримав би sh, і uvicorn
# не встиг би коректно дообробити запити (graceful shutdown, лаба 2).
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
