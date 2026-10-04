terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # Стан (terraform.tfstate) зберігається локально і НЕ комітиться:
  # у ньому є ідентифікатори ресурсів і можуть бути чутливі дані.
}

provider "aws" {
  region = var.region

  # Тег на кожному ресурсі — після destroy легко перевірити в консолі
  # (Resource Groups → Tag Editor), що нічого з проєкту не лишилось
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
