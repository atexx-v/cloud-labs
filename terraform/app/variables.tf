variable "region" {
  type    = string
  default = "eu-central-1"
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
  description = "Початкова кількість екземплярів; далі нею керує автоскейлінг"
  type        = number
  default     = 1
}

variable "min_instances" {
  type    = number
  default = 1
}

variable "max_instances" {
  type    = number
  default = 4
}

variable "cpu_target_percent" {
  description = "Цільове середнє завантаження CPU по сервісу, %"
  type        = number
  default     = 50
}

variable "scale_out_cooldown" {
  description = "Пауза після додавання екземпляра, с"
  type        = number
  default     = 60
}

variable "scale_in_cooldown" {
  description = "Пауза після вилучення екземпляра, с"
  type        = number
  default     = 300
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "cache_node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "cache_ttl_seconds" {
  description = "Час життя запису в кеші списку постів, с"
  type        = number
  default     = 30
}
