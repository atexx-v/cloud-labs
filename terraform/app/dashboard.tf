locals {
  ecs_dims = ["ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name]
  lb_dim   = ["LoadBalancer", aws_lb.main.arn_suffix]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.project

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Екземпляри: бажана і фактична кількість"
          region = var.region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            concat(["ECS/ContainerInsights", "DesiredTaskCount"], local.ecs_dims, [{ label = "Бажана" }]),
            concat(["ECS/ContainerInsights", "RunningTaskCount"], local.ecs_dims, [{ label = "Фактична" }]),
          ]
          yAxis = { left = { min = 0, max = var.max_instances + 1 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Завантаження CPU сервісу, %"
          region = var.region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            concat(["AWS/ECS", "CPUUtilization"], local.ecs_dims),
          ]
          yAxis       = { left = { min = 0, max = 100 } }
          annotations = { horizontal = [{ label = "Ціль автоскейлінгу", value = var.cpu_target_percent }] }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Запитів за хвилину"
          region  = var.region
          view    = "timeSeries"
          period  = 60
          stat    = "Sum"
          metrics = [concat(["AWS/ApplicationELB", "RequestCount"], local.lb_dim)]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Латентність p95, с"
          region  = var.region
          view    = "timeSeries"
          period  = 60
          stat    = "p95"
          metrics = [concat(["AWS/ApplicationELB", "TargetResponseTime"], local.lb_dim)]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title   = "Відповіді 5xx"
          region  = var.region
          view    = "timeSeries"
          period  = 60
          stat    = "Sum"
          metrics = [concat(["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count"], local.lb_dim)]
        }
      },
    ]
  })
}
