// The AWS external ALB which is the entrypoint for external traffic
resource "aws_alb" "external" {
  name            = format("%s%s", "lb-ext-", var.stack_identifier)
  internal        = false
  security_groups = [aws_security_group.lb-ext.id]
  subnets         = module.vpc.public_subnets

  tags = {
    Name = format("%s%s", "load-balancer-external-", var.stack_identifier)
  }
  idle_timeout = 600
}

// The HTTPS listener for the external ALB
resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_alb.external.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_iam_server_certificate.alb.arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/html"
      status_code  = "404"
    }
  }
}
// The HTTP listener for the external ALB with a redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_alb.external.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

// The security group for the external ALB
resource "aws_security_group" "lb-ext" {
  name        = format("%s%s%s", "lb-ext-", var.stack_identifier, "-sg")
  description = "SG for external load balancer"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_self_signed_cert" "alb" {
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.alb.private_key_pem

  subject {
    common_name  = "myloadbalancer"
    organization = "test.com"
  }

  validity_period_hours = 240

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "tls_private_key" "alb" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}




resource "aws_iam_server_certificate" "alb" {
  name             = format("%s%s", var.stack_identifier, "-lb-cert")
  certificate_body = tls_self_signed_cert.alb.cert_pem
  private_key      = tls_private_key.alb.private_key_pem
}

resource "aws_lb_listener_rule" "main" {
  listener_arn = aws_alb_listener.https.id
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ingress.arn
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

resource "aws_security_group_rule" "workstatio-to-lb" {
  description       = "Allow workstation to access lb https"
  security_group_id = aws_security_group.lb-ext.id
  cidr_blocks       = [format("%s/%s", data.external.myipaddr.result.ip, "32")]
  from_port         = 443
  protocol          = "tcp"
  to_port           = 443
  type              = "ingress"
}






