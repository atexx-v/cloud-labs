# Рівень акаунта: бюджет зі сповіщеннями.
#
# Окремо від terraform/app навмисно: app ми знищуємо після кожного заняття
# (terraform destroy), а бюджет має стерегти акаунт ЗАВЖДИ — зокрема тоді,
# коли щось забули видалити. Бюджет безкоштовний.
# Це перше, що створюється в акаунті (вимога методички).

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "cloud-labs"
      ManagedBy = "terraform"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "budget_email" {
  description = "Пошта для сповіщень про витрати"
  type        = string
}

variable "budget_limit_usd" {
  description = "Місячний ліміт у доларах"
  type        = number
  default     = 10
}

resource "aws_budgets_budget" "monthly" {
  name         = "cloud-labs-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Лист, коли фактично витрачено половину ліміту
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  # Лист, коли ліміт перевищено
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  # Лист заздалегідь: AWS прогнозує, що до кінця місяця ліміт буде перевищено
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
