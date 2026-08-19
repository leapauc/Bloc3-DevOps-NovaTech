resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Ingress public HTTP/HTTPS vers le load balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.certificate_arn != "" ? [1] : []
    content {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "this" {
  for_each = var.instance_ids

  # "blue" garde le nom EXISTANT ("${project_name}-tg", sans suffixe) : c'est
  # la target group qui existait déjà avant le Blue-Green (migrée en state).
  # name est ForceNew (immuable) sur une target group : lui donner un
  # suffixe la recréerait pour rien. Seul "green" (nouveau) a besoin d'un nom
  # distinct.
  name        = each.key == "blue" ? "${var.project_name}-tg" : "${var.project_name}-tg-${each.key}"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = each.key == "blue" ? "${var.project_name}-tg" : "${var.project_name}-tg-${each.key}"
  }
}

resource "aws_lb_target_group_attachment" "this" {
  for_each = var.instance_ids

  target_group_arn = aws_lb_target_group.this[each.key].arn
  target_id        = each.value
  port             = var.target_port
}

# HTTP : forward direct si pas de certif, sinon redirection vers HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.certificate_arn != "" ? null : aws_lb_target_group.this[var.active_color].arn
  }
}

resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[var.active_color].arn
  }
}
