# Керована PostgreSQL (завдання 2 і 3)

# Група підмереж: у яких підмережах RDS може розмістити базу — лише приватні
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project}-db"
  engine         = "postgres"
  engine_version = "16" # та сама мажорна версія, що й локально в compose
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true # шифрування диска — безкоштовне, немає причин вимикати

  db_name  = "blog"
  username = "blog"

  # Пароль генерує сам AWS і зберігає в Secrets Manager.
  # Його немає ні в коді, ні в terraform.tfvars, ні у стані Terraform.
  # Застосунок отримує його через ECS (див. secrets у ecs.tf).
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false # немає публічної адреси (завдання 3)

  # Multi-AZ (резервна копія в іншій зоні) подвоює ціну — для лаби вимкнено.
  # Бекап 1 день: увімкнено point-in-time recovery у межах доби.
  multi_az                = false
  backup_retention_period = 1

  # Щоб terraform destroy видаляв базу повністю і без зупинок.
  # У продакшені — навпаки: final snapshot і deletion_protection = true.
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true
}
