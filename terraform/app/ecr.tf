# Приватний реєстр образів (завдання 2)

resource "aws_ecr_repository" "app" {
  name = var.project

  # IMMUTABLE: тег не можна перезаписати. Тег = хеш коміту, тому кожен тег
  # завжди вказує на той самий код — відкат на попередню версію надійний
  image_tag_mutability = "IMMUTABLE"

  # Без цього terraform destroy впав би на непорожньому репозиторії
  force_delete = true

  # Сканування образу на відомі вразливості після кожного push
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Зберігати лише 10 останніх образів — сховище ECR платне
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
