# Mini Blog API — лабораторна 1 з хмарних технологій

REST API «міні-блог»: користувачі та їхні пости. Python 3.12, FastAPI, SQLAlchemy 2, Alembic, PostgreSQL 16.
Запускається локально через Docker Compose, у хмарі — AWS (ECS Fargate + RDS + ALB, Terraform, CD через GitHub Actions).

**Публічна адреса:** `terraform output app_url` (`http://…elb.amazonaws.com`).
_(Після `terraform destroy` застосунок недоступний; адреса з'являється після `apply`.)_
**Документація API (Swagger UI):** `/docs`

## Ендпоінти

| Метод | Шлях | Опис | Коди |
|---|---|---|---|
| GET | `/health` | Health check для балансувальника + ім'я екземпляра | 200 |
| POST | `/users` | Створити користувача `{email, name}` | 201, 409 email зайнятий, 422 |
| GET | `/users?limit=&offset=` | Список користувачів | 200 |
| GET | `/users/{id}` | Користувач | 200, 404 |
| GET | `/users/{id}/posts` | Пости користувача | 200, 404 |
| POST | `/posts` | Створити пост `{title, body, author_id}` | 201, 404 автора немає, 422 |
| GET | `/posts?limit=&offset=` | Список постів, найновіші першими | 200 |
| GET | `/posts/{id}` | Пост за id | 200, 404 |
| DELETE | `/posts/{id}` | Видалити пост | 204, 404 |

`limit` — від 1 до 100 (за замовчуванням 20).

## Локальний запуск

Потрібен лише Docker Desktop — Python на хості не потрібен.

```bash
cp .env.example .env          # один раз; змінити пароль
docker compose up -d --build
```

- API: http://localhost:8000 (перенаправляє на Swagger UI)
- При старті контейнер сам накатує міграції (`alembic upgrade head`)
- Дані — у volume `pgdata`: переживають `docker compose down`, видаляються лише `docker compose down -v`
- Порт бази назовні не опублікований

Приклад:
```bash
curl -X POST localhost:8000/users -H "Content-Type: application/json" \
  -d '{"email":"ann@example.com","name":"Ann"}'
curl -X POST localhost:8000/posts -H "Content-Type: application/json" \
  -d '{"title":"Перший пост","body":"Привіт з контейнера","author_id":1}'
curl localhost:8000/posts
```

Весь сценарій перевірки (створення, 409, 422, 404, видалення) виконує `./scripts/demo.sh <адреса>`.

## Архітектура в AWS

```
Інтернет ──:80 HTTP──▶ ALB (публічні підмережі, 2 зони)
                   │ health check /health
                   ▼ :8000
            ECS Fargate, ARM64 (приватні підмережі) ──:5432──▶ RDS PostgreSQL 16 (приватні підмережі)
                   │                                           пароль — у Secrets Manager
                   └──▶ NAT Gateway ──▶ ECR, Secrets Manager, CloudWatch Logs

GitHub Actions ──OIDC──▶ IAM-роль ──▶ ECR (образ:хеш_коміту) ──▶ оновлення ECS service
```

- З інтернету видно лише балансувальник. Контейнери й база не мають публічних адрес.
- Security group бази пускає лише security group застосунку, а та — лише security group ALB.
- Пароль до бази генерує AWS (RDS managed password) і зберігає в Secrets Manager; ECS передає його в контейнер як `DB_PASSWORD`.
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
cp terraform.tfvars.example terraform.tfvars   # вписати github_repo і github_oidc_subject_prefix
terraform init && terraform apply

# 3. Передати GitHub ARN ролі для деплою і запустити перший деплой
gh variable set AWS_ROLE_ARN --body "$(terraform output -raw github_deploy_role_arn)"
gh workflow run deploy.yml
terraform output app_url
```

Після першого `apply` сервіс ще не має образу (тег `bootstrap`). Перший `gh workflow run`
збирає образ, кладе його в ECR і оновлює сервіс. Далі кожен push у `main` деплоїться автоматично.

Прибрати все: `cd terraform/app && terraform destroy`. Разом з інфраструктурою Terraform видаляє й ревізії
task definition, які створив CI (ресурс `terraform_data.cleanup_task_definitions`); перевірити, що в акаунті нічого
не лишилось, можна скриптом `./scripts/verify-clean.sh`.
Бюджет у `terraform/account` можна лишити — він безкоштовний.

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
│   ├── config.py        # налаштування зі змінних середовища (DATABASE_URL або DB_*)
│   ├── db.py            # підключення до БД, сесія на запит
│   ├── models.py        # таблиці users і posts (SQLAlchemy)
│   ├── schemas.py       # формати запитів/відповідей (Pydantic)
│   └── routers/         # ендпоінти users і posts
├── alembic/versions/    # міграції схеми БД
├── tests/               # pytest
├── scripts/             # demo.sh (перевірка API), verify-clean.sh (чи все видалено)
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
