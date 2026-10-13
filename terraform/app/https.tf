# Увімкнено, лише коли задано domain_name і app_hostname; інакше застосунок працює по HTTP.
# HTTPS: ім'я застосунку в DNS і сертифікат для балансувальника.
# Зона DNS і сертифікат створені в terraform/account (живуть постійно), тут вони лише читаються.

data "aws_route53_zone" "main" {
  count = local.https ? 1 : 0
  name  = var.domain_name
}

# Сертифікат має бути в статусі ISSUED, тобто валідацію в terraform/account вже пройдено
data "aws_acm_certificate" "app" {
  count       = local.https ? 1 : 0
  domain      = var.app_hostname
  statuses    = ["ISSUED"]
  most_recent = true
}

# Alias-запис: lab.example.com → балансувальник. Адреса ALB змінюється після кожного
# apply, але запис оновлюється разом з ним, тож для користувача адреса стабільна.
resource "aws_route53_record" "app" {
  count   = local.https ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.app_hostname
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
