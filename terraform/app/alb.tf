# Application Load Balancer (завдання 4) — єдина точка входу з інтернету

resource "aws_lb" "main" {
  name               = "${var.project}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project}-app"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Fargate реєструє в групі IP-адреси задач, а не EC2-інстанси

  # Скільки чекати, поки екземпляр, що вилучається, дообробить запити.
  # За замовчуванням 300 с — деплой тягнувся б на 5 хвилин довше
  deregistration_delay = 30

  # ALB раз на 15 с запитує /health у кожного екземпляра.
  # 3 невдачі поспіль → екземпляр «unhealthy», трафік на нього не йде,
  # а ECS замінює його новим. 2 успіхи → знову отримує трафік.
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
