output "app_url" {
  description = "Публічна адреса застосунку (DNS-ім'я балансувальника)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "github_deploy_role_arn" {
  description = "Вписати в GitHub: Settings → Secrets and variables → Actions → Variables → AWS_ROLE_ARN"
  value       = aws_iam_role.github_deploy.arn
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service" {
  value = aws_ecs_service.app.name
}

output "db_address" {
  description = "Адреса RDS — доступна лише зсередини VPC"
  value       = aws_db_instance.main.address
}

output "dashboard_url" {
  description = "Дашборд моніторингу в консолі AWS"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
