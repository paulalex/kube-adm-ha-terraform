resource "aws_alb_target_group" "ingress" {
  name                 = format("%s%s", var.stack_identifier, "-ingress-tg")
  port                 = var.ingress_port
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = module.vpc.vpc_id
  deregistration_delay = "30"

  health_check {
    healthy_threshold   = "2"
    unhealthy_threshold = "3"
    interval            = "30"
    matcher             = "404"
    path                = "/healthz"
    protocol            = "HTTP"
  }

  tags = {
    Name = "traefik-web-target-group"
  }
}



