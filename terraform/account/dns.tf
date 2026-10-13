# DNS-зона і TLS-сертифікат для HTTPS.
#
# Живуть тут, а не в terraform/app, свідомо: app ми знищуємо після кожного заняття, а зона DNS
# має лишатись, бо її серверів імен (NS) ви один раз вписуєте в реєстратора домену.
# Якби зона пересоздавалась разом з app, NS щоразу були б новими і домен «відвалювався» б.
# Вартість: зона Route 53 ≈ $0,5/міс, сертифікат ACM безкоштовний.

variable "domain_name" {
  description = "Ваш домен, напр. example.com (для нього створюється DNS-зона)"
  type        = string
}

variable "app_hostname" {
  description = "Повне ім'я застосунку, напр. lab.example.com (на нього видається сертифікат)"
  type        = string
}

resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# Сертифікат видається на ім'я застосунку; право на домен підтверджується DNS-записом
resource "aws_acm_certificate" "app" {
  domain_name       = var.app_hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Запис, яким ACM переконується, що домен ваш
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for o in aws_acm_certificate.app.domain_validation_options : o.domain_name => o
  }

  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60
  allow_overwrite = true
}

# Чекає, поки ACM побачить запис і видасть сертифікат. Це спрацює лише ПІСЛЯ того, як у реєстратора
# вказано name_servers нижче (інакше світ не бачить наш запис, і очікування завершиться помилкою).
resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

output "name_servers" {
  description = "Вписати ці 4 сервери імен у реєстратора домену (Custom DNS / Nameservers)"
  value       = aws_route53_zone.main.name_servers
}
