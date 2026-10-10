data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "${path.module}/../01-network/terraform.tfstate"
  }
}

locals {
  net = data.terraform_remote_state.network.outputs

  public_web_userdata = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf install -y nginx
    cat >/usr/share/nginx/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Public ACM path</title></head>
    <body>
      <h1>Public ACM path</h1>
      <p>TLS terminated on the ALB with an ACM public certificate.</p>
      <p>Host: ${var.public_hostname}</p>
    </body>
    </html>
    HTML
    systemctl enable --now nginx
  EOF
}

resource "aws_acm_certificate" "public" {
  domain_name       = var.public_hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-public"
  }
}

# Public hosted zone must be in the same account as this apply (route53_zone_id).
resource "aws_route53_record" "public_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.public.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "public" {
  certificate_arn         = aws_acm_certificate.public.arn
  validation_record_fqdns = [for record in aws_route53_record.public_cert_validation : record.fqdn]
}

resource "aws_lb" "public" {
  name               = "${var.name_prefix}-public"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [local.net.alb_security_group_id]
  subnets            = local.net.public_subnet_ids

  tags = {
    Name = "${var.name_prefix}-public"
  }
}

resource "aws_lb_target_group" "public" {
  name     = "${var.name_prefix}-public"
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.net.vpc_id

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "public_https" {
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.public.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.public.arn
  }
}

resource "aws_instance" "public_web" {
  ami                    = local.net.ami_id
  instance_type          = var.instance_type
  subnet_id              = local.net.private_subnet_ids[0]
  vpc_security_group_ids = [local.net.public_web_security_group_id]
  iam_instance_profile   = local.net.ssm_instance_profile_name
  user_data              = local.public_web_userdata

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.name_prefix}-public-web"
  }
}

resource "aws_lb_target_group_attachment" "public" {
  target_group_arn = aws_lb_target_group.public.arn
  target_id        = aws_instance.public_web.id
  port             = 80
}

resource "aws_route53_record" "public" {
  zone_id = var.route53_zone_id
  name    = var.public_hostname
  type    = "A"

  alias {
    name                   = aws_lb.public.dns_name
    zone_id                = aws_lb.public.zone_id
    evaluate_target_health = true
  }
}
