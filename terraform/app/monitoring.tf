# Моніторинг (бонус 7): логи (CloudWatch Logs у ecs.tf), дашборд і алерти на email.

locals {
  alb_dim = aws_lb.main.arn_suffix
  tg_dim  = aws_lb_target_group.app.arn_suffix
}

# --- Алерти: правило стежить за метрикою, SNS розсилає листи ---

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
}

# Після apply AWS надішле лист із посиланням підтвердження підписки.
# Поки не натиснути — листи алертів НЕ доставляються.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Помилки 5xx від застосунку: 3 і більше за хвилину.
# treat_missing_data = notBreaching: немає запитів — немає даних — це не аварія
resource "aws_cloudwatch_metric_alarm" "errors_5xx" {
  alarm_name          = "${var.project}-5xx-errors"
  alarm_description   = "Застосунок повертає помилки 5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = local.alb_dim, TargetGroup = local.tg_dim }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn] # лист і про відновлення
}

# Балансувальник вважає екземпляр нездоровим (не проходить health check /health)
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project}-unhealthy-hosts"
  alarm_description   = "Екземпляр застосунку не проходить health check"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = local.alb_dim, TargetGroup = local.tg_dim }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2 # дві хвилини поспіль — щоб короткий збій під час деплою не спамив
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# --- Дашборд ---

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.project

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 8, height = 6
        properties = {
          title  = "Запити за хвилину"
          region = var.region
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_dim],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 0, width = 8, height = 6
        properties = {
          title  = "Помилки 5xx"
          region = var.region
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.alb_dim, "TargetGroup", local.tg_dim, { label = "5xx від застосунку" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.alb_dim, { label = "5xx від балансувальника" }],
          ]
        }
      },
      {
        type = "metric", x = 16, y = 0, width = 8, height = 6
        properties = {
          title  = "Латентність (секунди)"
          region = var.region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_dim, "TargetGroup", local.tg_dim, { stat = "p50", label = "p50" }],
            ["...", { stat = "p95", label = "p95" }],
            ["...", { stat = "p99", label = "p99" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 8, height = 6
        properties = {
          title  = "CPU, %"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 6, width = 8, height = 6
        properties = {
          title  = "Пам'ять, %"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name],
          ]
        }
      },
      {
        type = "metric", x = 16, y = 6, width = 8, height = 6
        properties = {
          title  = "Здорові / нездорові екземпляри"
          region = var.region
          view   = "timeSeries"
          stat   = "Maximum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", local.alb_dim, "TargetGroup", local.tg_dim],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", local.alb_dim, "TargetGroup", local.tg_dim],
          ]
        }
      },
      {
        type = "log", x = 0, y = 12, width = 24, height = 6
        properties = {
          title  = "Останні логи застосунку"
          region = var.region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields @timestamp, @message | sort @timestamp desc | limit 30"
        }
      },
    ]
  })
}
