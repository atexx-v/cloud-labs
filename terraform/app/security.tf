# Security groups — брандмауер на рівні кожного ресурсу (завдання 3 і 4).
#
#   інтернет ──:80──▶ [alb] ──:8000──▶ [app] ──:5432──▶ [db]
#
# Правила посилаються на security group, а не на IP-діапазони: адреси
# контейнерів змінюються при кожному деплої, а членство в групі — ні.
# Terraform видаляє стандартне правило AWS «весь вихідний трафік дозволено»,
# тому кожен дозволений напрямок описаний явно.

resource "aws_security_group" "alb" {
  name        = "${var.project}-alb"
  description = "ALB: HTTP from the internet"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "app" {
  name        = "${var.project}-app"
  description = "App containers: traffic only from ALB"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "db" {
  name        = "${var.project}-db"
  description = "RDS: PostgreSQL only from app containers"
  vpc_id      = aws_vpc.main.id
}

# --- ALB ---

# Єдине правило в усьому проєкті, відкрите для всього інтернету
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests and health checks to app"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
}

# --- Застосунок ---

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Only from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL"
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# HTTPS назовні (через NAT) — до API AWS: ECR, Secrets Manager, CloudWatch Logs, SSM (ECS Exec)
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to AWS APIs via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# --- База даних ---

# Дослівна вимога завдання 3: підключення лише від security group застосунку
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "Only from app security group"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
# Вихідних правил для БД немає: вона сама нікуди не підключається
