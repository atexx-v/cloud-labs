variable "region" {
  type    = string
  default = "eu-central-1" # Франкфурт — найближчий до України регіон
}

variable "project" {
  description = "Префікс імен ресурсів. Має збігатися зі змінними в .github/workflows/deploy.yml"
  type        = string
  default     = "cloud-labs"
}

variable "github_repo" {
  description = "Репозиторій у форматі власник/назва — лише йому дозволено деплоїти через OIDC"
  type        = string
}

variable "github_oidc_subject_prefix" {
  description = <<-EOT
    Префікс sub-claim OIDC-токена GitHub для цього репозиторію. Новим репозиторіям GitHub видає
    незмінний формат з числовими id: repo:<власник>@<id>/<репо>@<id>. Дізнатись:
    gh api repos/<власник>/<репо>/actions/oidc/customization/sub  → поле sub_claim_prefix
  EOT
  type        = string
}

variable "image_tag" {
  description = "Тег образу для першого запуску. Далі тег (хеш коміту) підставляє CI"
  type        = string
  default     = "bootstrap"
}

variable "app_cpu" {
  description = "CPU задачі Fargate у одиницях: 256 = 0.25 vCPU"
  type        = number
  default     = 256
}

variable "app_memory" {
  description = "Пам'ять задачі Fargate, МБ"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Кількість екземплярів застосунку"
  type        = number
  default     = 1
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro" # найменший клас; Graviton (ARM) — дешевший
}

variable "alert_email" {
  description = "Пошта для алертів моніторингу (після apply підтвердити підписку з листа AWS)"
  type        = string
}
