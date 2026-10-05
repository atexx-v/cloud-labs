# Mini Blog API — лабораторні з хмарних технологій

REST API «міні-блог»: користувачі та їхні пости. Python 3.12, FastAPI, SQLAlchemy 2, Alembic, PostgreSQL 16.
Запускається локально через Docker Compose, у хмарі — AWS (ECS Fargate + RDS + ALB, Terraform).

**Публічна адреса:** http://cloud-labs-alb-1943946083.eu-central-1.elb.amazonaws.com
_(адреса балансувальника змінюється після `terraform destroy` + `apply`; актуальна — `terraform output app_url`. Після захисту ресурси видаляються, тож адреса може бути недоступна.)_
**Документація API (Swagger UI):** `/docs`

## Ендпоінти

Читання відкрите всім, запис потребує JWT-токена (`Authorization: Bearer <токен>`).
Без токена захищені ендпоінти повертають **401**.

| Метод | Шлях | Опис | Автент. | Коди |
|---|---|---|---|---|
| GET | `/health` | Health check для балансувальника + ім'я екземпляра | — | 200 |
| POST | `/auth/register` | Реєстрація `{email, name, password≥8}` | — | 201, 409 email зайнятий, 422 |
| POST | `/auth/login` | Вхід `{email, password}` → `{access_token}` (діє 60 хв) | — | 200, 401 |
| GET | `/auth/me` | Поточний користувач | ✔ | 200, 401 |
| GET | `/users?limit=&offset=` | Список користувачів | — | 200 |
| GET | `/users/{id}` | Користувач (дані автора) | — | 200, 404 |
| GET | `/users/{id}/posts` | Пости користувача | — | 200, 404 |
| POST | `/posts` | Створити пост `{title, body}`; автор — власник токена | ✔ | 201, 401, 422 |
| GET | `/posts?limit=&offset=` | Список постів, найновіші першими | — | 200 |
| GET | `/posts/{id}` | Пост за id | — | 200, 404 |
| DELETE | `/posts/{id}` | Видалити власний пост | ✔ | 204, 401, 403 чужий, 404 |

`limit` — від 1 до 100 (за замовчуванням 20). У Swagger UI (`/docs`) кнопка **Authorize** підставляє токен.

Паролі зберігаються як scrypt-хеш із сіллю. Ключ підпису JWT (`JWT_SECRET`) в AWS генерує Terraform
і кладе в Secrets Manager; локально береться з `.env`.

## Моніторинг

CloudWatch: логи контейнера (`/ecs/cloud-labs`), дашборд `cloud-labs` (запити, 5xx, латентність p50/p95/p99,
CPU, пам'ять, здорові екземпляри, останні логи) і два алерти на email через SNS — помилки 5xx та
нездорові екземпляри. Усе в `terraform/app/monitoring.tf`. Після `apply` треба підтвердити підписку
SNS у листі від AWS.

## Локальний запуск

Потрібен лише Docker Desktop — Python на хості не потрібен.

```bash
cp .env.example .env          # один раз; змінити пароль і JWT_SECRET (openssl rand -hex 32)
docker compose up -d --build
```

- API: http://localhost:8000 (перенаправляє на Swagger UI)
- При старті контейнер сам накатує міграції (`alembic upgrade head`)
- Дані — у volume `pgdata`: переживають `docker compose down`, видаляються лише `docker compose down -v`
- Порт бази назовні не опублікований

Приклад:
```bash
curl -X POST localhost:8000/auth/register -H "Content-Type: application/json" \
  -d '{"email":"ann@example.com","name":"Ann","password":"correct-horse"}'
TOKEN=$(curl -s -X POST localhost:8000/auth/login -H "Content-Type: application/json" \
  -d '{"email":"ann@example.com","password":"correct-horse"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
curl -X POST localhost:8000/posts -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"Перший пост","body":"Привіт з контейнера"}'
curl localhost:8000/posts
```

## Архітектура в AWS

```
Інтернет ──:80──▶ ALB (публічні підмережі, 2 зони)
                   │ health check /health
                   ▼ :8000
            ECS Fargate, ARM64 (приватні підмережі) ──:5432──▶ RDS PostgreSQL 16 (приватні підмережі)
                   │                                           пароль — у Secrets Manager
                   └──▶ NAT Gateway ──▶ ECR, Secrets Manager, CloudWatch Logs

GitHub Actions ──OIDC──▶ IAM-роль ──▶ ECR (образ:хеш_коміту) ──▶ оновлення ECS service
```

- З інтернету видно лише балансувальник. Контейнери й база не мають публічних адрес.
- Security group бази пускає лише security group застосунку, а та — лише security group ALB.
- Пароль до бази генерує AWS (RDS managed password); ECS передає його в контейнер як `DB_PASSWORD`.
- CI/CD не має збережених ключів: GitHub отримує тимчасові облікові дані через OIDC.

## Розгортання з нуля

Потрібні: AWS CLI з налаштованим IAM-користувачем (`aws sts get-caller-identity`), Terraform ≥ 1.9, gh.

```bash
# 1. Бюджет зі сповіщеннями — один раз, не видаляється між заняттями
cd terraform/account
cp terraform.tfvars.example terraform.tfvars   # вписати пошту
terraform init && terraform apply

# 2. Уся інфраструктура лаби (~10–15 хв, найдовше створюється RDS)
cd ../app
cp terraform.tfvars.example terraform.tfvars   # вписати github_repo
terraform init && terraform apply

# 3. Передати GitHub ARN ролі для деплою і запустити перший деплой
gh variable set AWS_ROLE_ARN --body "$(terraform output -raw github_deploy_role_arn)"
gh workflow run deploy.yml
terraform output app_url
```

Після першого `apply` сервіс ще не має образу (тег `bootstrap`). Перший `gh workflow run`
збирає образ, кладе його в ECR і оновлює сервіс. Далі кожен push у `main` деплоїться автоматично.

Прибрати все: `terraform destroy` у `terraform/app` (бюджет у `terraform/account` можна лишити — він безкоштовний).

## Тести

Працюють на SQLite у пам'яті, без Docker і Postgres:
```bash
python -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
pytest
```

## Структура

```
.
├── app/
│   ├── main.py          # створення FastAPI, /health
│   ├── security.py      # хешування паролів (scrypt), створення і перевірка JWT
│   ├── auth.py          # залежність get_current_user (401 без дійсного токена)
│   ├── config.py        # налаштування зі змінних середовища (DATABASE_URL або DB_*)
│   ├── db.py            # підключення до БД, сесія на запит
│   ├── models.py        # таблиці users і posts (SQLAlchemy)
│   ├── schemas.py       # формати запитів/відповідей (Pydantic)
│   └── routers/         # ендпоінти users і posts
├── alembic/versions/    # міграції схеми БД
├── tests/               # pytest
├── terraform/
│   ├── account/         # бюджет зі сповіщеннями (живе постійно)
│   └── app/             # мережа, security groups, ECR, RDS, ECS, ALB, OIDC-роль для CI
├── .github/workflows/
│   └── deploy.yml       # тести → образ у ECR → деплой в ECS
├── Dockerfile
├── docker-entrypoint.sh # міграції → запуск uvicorn
├── compose.yaml         # застосунок + PostgreSQL локально
└── .env.example         # шаблон секретів (сам .env не комітиться)
```
