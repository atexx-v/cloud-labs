# Доступ GitHub Actions до AWS без збережених ключів (завдання 5).
#
# Як це працює:
# 1. GitHub видає кожному запуску workflow короткоживучий підписаний токен (OIDC/JWT),
#    у якому записано, з якого репозиторію і гілки він запущений.
# 2. AWS довіряє підпису GitHub (provider нижче) і за умовами trust policy
#    перевіряє, що токен саме від нашого репозиторію і гілки main.
# 3. Взамін AWS видає тимчасові облікові дані ролі на ~1 годину.
# Постійних access keys немає ніде — нічого вкрасти з GitHub Secrets.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Trust policy: ХТО може отримати роль
data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Лише наш репозиторій і лише гілка main: workflow з форку чи іншої гілки роль не отримає.
    # Префікс — незмінний (з id репозиторію): якщо власник перейменує репо, а ім'я займе
    # хтось інший, старий trust policy на нього не поширюється
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${var.github_oidc_subject_prefix}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "${var.project}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

# Permissions policy: ЩО роль може робити — рівно те, що потрібно для деплою
data "aws_iam_policy_document" "github_deploy" {
  # Логін у ECR — ця дія не обмежується конкретним ресурсом
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Завантажити образ — лише в наш репозиторій
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  # Зареєструвати нову ревізію task definition (дії без обмеження за ресурсом)
  statement {
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  # Оновити лише наш сервіс
  statement {
    actions   = ["ecs:DescribeServices", "ecs:UpdateService"]
    resources = [aws_ecs_service.app.id]
  }

  # Нова ревізія task definition посилається на ролі задачі — передати можна лише їх і лише в ECS
  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.task_execution.arn, aws_iam_role.task.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
