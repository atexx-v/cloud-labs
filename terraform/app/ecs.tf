# Запуск контейнера: ECS Fargate (завдання 2)

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7 # зберігання логів платне; тиждень достатньо для лаби
}

resource "aws_ecs_cluster" "main" {
  name = var.project
}

# --- IAM-ролі ---

# Обидві ролі може «приміряти» лише сервіс ECS Tasks
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role — права самого ECS ДО запуску контейнера:
# стягнути образ з ECR, прочитати секрет, створити потік логів
resource "aws_iam_role" "task_execution" {
  name               = "${var.project}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Читати можна лише один секрет — пароль нашої бази (принцип найменших привілеїв)
data "aws_iam_policy_document" "read_db_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.main.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_role_policy" "task_execution_db_secret" {
  name   = "read-db-secret"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.read_db_secret.json
}

# Task role — права коду застосунку ПІД ЧАС роботи.
# Застосунку AWS API не потрібні; єдине — канал для ECS Exec,
# щоб на захисті зайти в контейнер і показати дані в приватній базі
resource "aws_iam_role" "task" {
  name               = "${var.project}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "ecs_exec" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"] # ці дії не підтримують обмеження за ресурсом
  }
}

resource "aws_iam_role_policy" "task_ecs_exec" {
  name   = "ecs-exec"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.ecs_exec.json
}

# --- Task definition: «рецепт» запуску контейнера ---

resource "aws_ecs_task_definition" "app" {
  family                   = var.project
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # кожна задача отримує власний мережевий інтерфейс і IP
  cpu                      = var.app_cpu
  memory                   = var.app_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  # ARM64 (Graviton): дешевше за x86 і та сама архітектура, що й Mac на Apple Silicon
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{ containerPort = 8000, protocol = "tcp" }]

    # Несекретні параметри підключення — звичайні змінні середовища
    environment = [
      { name = "DB_HOST", value = aws_db_instance.main.address },
      { name = "DB_PORT", value = tostring(aws_db_instance.main.port) },
      { name = "DB_NAME", value = aws_db_instance.main.db_name },
      { name = "DB_USER", value = aws_db_instance.main.username },
      { name = "DB_SSLMODE", value = "require" },
    ]

    # Пароль: ECS сам читає його з Secrets Manager при старті задачі.
    # ":password::" — взяти з JSON-секрету лише поле password
    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = "${aws_db_instance.main.master_user_secret[0].secret_arn}:password::"
    }]

    # stdout контейнера → CloudWatch Logs
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "app"
      }
    }
  }])
}

# --- Service: тримає потрібну кількість запущених задач ---

resource "aws_ecs_service" "app" {
  name            = var.project
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  enable_execute_command = true # ECS Exec — зайти в контейнер на захисті

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false # контейнер не видно з інтернету — лише через ALB
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 8000
  }

  # Час на старт (міграції + запуск uvicorn), перш ніж health check ALB почне рахуватись
  health_check_grace_period_seconds = 60

  # Якщо нова версія не проходить health check — ECS сам відкочує на попередню
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Listener має існувати раніше за сервіс, інакше ECS не зможе підключитись до ALB
  depends_on = [aws_lb_listener.http]

  lifecycle {
    # Нові ревізії task definition (з новим тегом образу) реєструє CI.
    # Без ignore_changes наступний terraform apply відкотив би сервіс
    # на ревізію з тегом "bootstrap"
    ignore_changes = [task_definition]
  }
}
