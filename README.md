# Mini Blog API

Невеликий REST API для блогу: користувачі й пости. Написаний на Python 3.12 (FastAPI, SQLAlchemy 2, Alembic) з PostgreSQL 16.
Локально все піднімається однією командою через Docker Compose, а в хмарі працює на AWS: ECS Fargate, RDS, ALB і Redis,
усе описано в Terraform, а деплоїться через GitHub Actions.

Це моя робота з хмарних технологій. Лабораторна 1 — контейнер, Terraform, база, балансувальник і CD.
Лабораторна 2 — автоскейлінг, навантажувальний тест, дашборд, алерти й кеш (розділ про неї нижче).

Адреса застосунку в хмарі з'являється після `terraform apply` (`terraform output app_url`). Поки інфраструктура
не піднята, вона недоступна: після захисту я роблю `terraform destroy`, щоб не платити за простій.
Документація API (Swagger UI) лежить на `/docs`.

## Що вміє API

| Метод | Шлях | Що робить | Коди відповіді |
|---|---|---|---|
| GET | `/health` | перевірка для балансувальника, повертає ім'я екземпляра | 200 |
| POST | `/users` | створює користувача `{email, name}` | 201, 409 (email зайнятий), 422 |
| GET | `/users?limit=&offset=` | список користувачів | 200 |
| GET | `/users/{id}` | один користувач | 200, 404 |
| GET | `/users/{id}/posts` | пости користувача | 200, 404 |
| POST | `/posts` | створює пост `{title, body, author_id}` | 201, 404 (автора немає), 422 |
| GET | `/posts?limit=&offset=` | список постів, найновіші першими | 200 |
| GET | `/posts/{id}` | пост за id | 200, 404 |
| DELETE | `/posts/{id}` | видаляє пост | 204, 404 |

`limit` може бути від 1 до 100, за замовчуванням 20.

## Запуск на своєму комп'ютері

Потрібен лише Docker Desktop, Python на машині ставити не треба.

```bash
cp .env.example .env          # один раз, і замінити пароль
docker compose up -d --build
```

API відкриється на http://localhost:8000 і одразу перекине на Swagger. Міграції контейнер накатує сам при старті
(`alembic upgrade head`). Дані лежать у volume `pgdata`, тож переживають `docker compose down`; стираються
вони тільки через `docker compose down -v`. Порт бази назовні я не відкривав.

Швидка перевірка руками:

```bash
curl -X POST localhost:8000/users -H "Content-Type: application/json" \
  -d '{"email":"ann@example.com","name":"Ann"}'
curl -X POST localhost:8000/posts -H "Content-Type: application/json" \
  -d '{"title":"Перший пост","body":"Привіт з контейнера","author_id":1}'
curl localhost:8000/posts
```

А `./scripts/demo.sh <адреса>` проганяє весь сценарій: створення, 409, 422, 404 і видалення.

## Як це влаштовано в AWS

```
Інтернет ──:80──▶ ALB (публічні підмережі, 2 зони)
                   │ перевірка /health
                   ▼ :8000
            ECS Fargate, ARM64 (приватні підмережі) ──:5432──▶ RDS PostgreSQL 16
                   │                                           пароль у Secrets Manager
                   ├──:6379──▶ ElastiCache Redis (кеш)
                   └──▶ NAT Gateway ──▶ ECR, Secrets Manager, CloudWatch Logs

GitHub Actions ──OIDC──▶ IAM-роль ──▶ ECR (образ з тегом = хеш коміту) ──▶ оновлення ECS service
```

З інтернету видно лише балансувальник. Контейнери, база й Redis публічних адрес не мають. Доступ закритий ланцюжком
security group: до бази пускає тільки група застосунку, до застосунку тільки група ALB.

Пароль до бази генерує сам AWS (RDS managed password) і кладе в Secrets Manager, а ECS передає його в контейнер
змінною `DB_PASSWORD`. У CI/CD жодних збережених ключів немає: GitHub отримує тимчасові облікові дані через OIDC,
причому тільки для гілки `main`.

## Розгортання з нуля

Потрібні AWS CLI з налаштованим IAM-користувачем (перевірити: `aws sts get-caller-identity`), Terraform 1.9 або новіший і gh.

```bash
# 1. Бюджет зі сповіщеннями. Робиться один раз і між заняттями не видаляється
cd terraform/account
cp terraform.tfvars.example terraform.tfvars   # вписати свою пошту
terraform init && terraform apply

# 2. Уся інфраструктура лаби (10–15 хвилин, найдовше піднімається RDS)
cd ../app
cp terraform.tfvars.example terraform.tfvars   # вписати github_repo, github_oidc_subject_prefix і alert_email
terraform init && terraform apply

# 3. Віддати GitHub ARN ролі для деплою й запустити перший деплой
gh variable set AWS_ROLE_ARN --body "$(terraform output -raw github_deploy_role_arn)"
gh workflow run deploy.yml
terraform output app_url
```

Одразу після `apply` в ECR ще немає образу застосунку (є лише тег `bootstrap`). Перший запуск `deploy.yml` збирає образ,
кладе його в ECR і оновлює сервіс. Далі кожен push у `main` деплоїться сам. Якщо змінної `AWS_ROLE_ARN` у репозиторії
нема, job `deploy` просто пропускається, а тести все одно біжать.

Знести все: `cd terraform/app && terraform destroy`. Разом з інфраструктурою Terraform прибирає й ревізії task definition,
які створив CI. Що в акаунті справді нічого не лишилось, показує `./scripts/verify-clean.sh`.
Бюджет у `terraform/account` можна лишити, він безкоштовний.

## Тести

Вони йдуть на SQLite в пам'яті, а Redis підміняє fakeredis, тому ні Docker, ні Postgres не потрібні:

```bash
python -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
pytest
```

## Лабораторна 2: масштабування, моніторинг, кеш

Усе, що додалось у другій лабі, і де це шукати:

- **Автоскейлінг.** ECS Service Auto Scaling тримає від 1 до 4 екземплярів так, щоб середнє CPU було близько 50 %.
  Код у `terraform/app/autoscaling.tf`, пояснення, графіки й розбір затримок у [docs/AUTOSCALING.md](docs/AUTOSCALING.md).
- **Навантажувальний тест.** Locust імітує 60 користувачів у профілі «мало записів, багато читань».
  Сценарій і запуск у `loadtest/`, опис у [docs/LOADTEST.md](docs/LOADTEST.md).
- **Дашборд CloudWatch.** П'ять графіків (екземпляри, CPU, запити, латентність p95, 5xx) описані в `terraform/app/dashboard.tf`.
- **Алерти.** Якщо CPU тримається вище 70 % дві хвилини поспіль, тривога CloudWatch через SNS шле лист
  (і ще один, коли все нормалізується). Код у `terraform/app/alerts.tf`, листи зі знімками в [docs/ALERTS.md](docs/ALERTS.md).
- **Кеш.** `GET /posts` кешується в Redis (ElastiCache) за схемою cache-aside на 30 секунд. На тому самому навантаженні
  p95 впав з 390 до 130 мс, а CPU контейнера з 96 до 57 %. Код у `app/cache.py` і `terraform/app/cache.tf`,
  порівняння прогонів у [docs/CACHE.md](docs/CACHE.md).

Одне чесне спостереження з тестів: автоскейлінг реагує не миттєво. Від моменту, коли CPU перетнув ціль, до появи нових
екземплярів минало приблизно п'ять хвилин, а назад до одного екземпляра сервіс повертався майже пів години.
Чому так, розписано в docs/AUTOSCALING.md.

## Структура проєкту

```
.
├── app/
│   ├── main.py          # створення FastAPI, /health
│   ├── config.py        # налаштування зі змінних середовища
│   ├── db.py            # підключення до БД, сесія на запит
│   ├── models.py        # таблиці users і posts (SQLAlchemy)
│   ├── schemas.py       # формати запитів і відповідей (Pydantic)
│   ├── cache.py         # клієнт Redis, get/set
│   └── routers/         # ендпоінти users і posts
├── alembic/versions/    # міграції схеми БД
├── tests/               # pytest
├── loadtest/            # сценарій Locust, run.sh, результати прогонів
├── docs/                # документи до лаби 2 і знімки до них
├── scripts/             # demo.sh (перевірка API), verify-clean.sh (чи все видалено)
├── terraform/
│   ├── account/         # бюджет зі сповіщеннями (живе постійно)
│   └── app/             # мережа, ECR, RDS, ECS, ALB, автоскейлінг, Redis, дашборд, алерти, OIDC-роль
├── .github/workflows/
│   └── deploy.yml       # тести → образ у ECR → деплой в ECS
├── Dockerfile
├── docker-entrypoint.sh # міграції, потім uvicorn
├── compose.yaml         # застосунок і PostgreSQL локально
└── .env.example         # шаблон секретів (сам .env у git не потрапляє)
```
