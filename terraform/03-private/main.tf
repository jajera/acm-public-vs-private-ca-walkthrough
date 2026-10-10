data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "${path.module}/../01-network/terraform.tfstate"
  }
}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

locals {
  net = data.terraform_remote_state.network.outputs

  mode_alb   = var.private_tls_mode == "alb_acm"
  mode_nginx = var.private_tls_mode == "nginx_export"

  # app.internal.johna.kiwi → internal.johna.kiwi (VPC-only private hosted zone)
  private_hostname_labels = split(".", var.private_hostname)
  private_zone_name = join(
    ".",
    slice(local.private_hostname_labels, 1, length(local.private_hostname_labels)),
  )

  configure_private_web_script = file("${path.module}/../../scripts/configure-private-web.sh")

  # alb_acm: HTTP-only backend (mirror public-web). No leaf material in user data.
  private_web_http_userdata = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf install -y nginx
    cat >/usr/share/nginx/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Private CA path (ALB)</title></head>
    <body>
      <h1>Private CA path</h1>
      <p>TLS terminated on the internal ALB with an ACM private certificate.</p>
      <p>Host: ${var.private_hostname}</p>
      <p>Backend is HTTP only — same pattern as the public ACM path.</p>
    </body>
    </html>
    HTML
    systemctl enable --now nginx
  EOF
}

resource "aws_route53_zone" "private" {
  name = local.private_zone_name

  vpc {
    vpc_id = local.net.vpc_id
  }

  tags = {
    Name = "${var.name_prefix}-private-zone"
  }
}

resource "aws_acmpca_certificate_authority" "root" {
  type       = "ROOT"
  usage_mode = "GENERAL_PURPOSE"

  certificate_authority_configuration {
    key_algorithm     = "RSA_2048"
    signing_algorithm = "SHA256WITHRSA"

    subject {
      common_name         = "${var.name_prefix} Lab Root CA"
      organization        = "jajera"
      organizational_unit = "acm-lab"
      country             = "NZ"
    }
  }

  permanent_deletion_time_in_days = 7

  tags = {
    Name = "${var.name_prefix}-root-ca"
  }
}

resource "aws_acmpca_certificate" "root" {
  certificate_authority_arn   = aws_acmpca_certificate_authority.root.arn
  certificate_signing_request = aws_acmpca_certificate_authority.root.certificate_signing_request
  signing_algorithm           = "SHA256WITHRSA"

  template_arn = "arn:${data.aws_partition.current.partition}:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 5
  }
}

resource "aws_acmpca_certificate_authority_certificate" "root" {
  certificate_authority_arn = aws_acmpca_certificate_authority.root.arn
  certificate               = aws_acmpca_certificate.root.certificate
  certificate_chain         = aws_acmpca_certificate.root.certificate_chain
}

# ---------------------------------------------------------------------------
# alb_acm (default): ACM private cert on internal ALB → HTTP private-web
# ---------------------------------------------------------------------------

resource "aws_acmpca_permission" "acm" {
  count = local.mode_alb ? 1 : 0

  certificate_authority_arn = aws_acmpca_certificate_authority.root.arn
  actions                   = ["IssueCertificate", "GetCertificate", "ListPermissions"]
  principal                 = "acm.amazonaws.com"
  source_account            = data.aws_caller_identity.current.account_id

  depends_on = [aws_acmpca_certificate_authority_certificate.root]
}

resource "aws_acm_certificate" "private" {
  count = local.mode_alb ? 1 : 0

  domain_name               = var.private_hostname
  certificate_authority_arn = aws_acmpca_certificate_authority.root.arn

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-private-acm"
  }

  depends_on = [
    aws_acmpca_certificate_authority_certificate.root,
    aws_acmpca_permission.acm,
  ]
}

resource "aws_lb" "internal" {
  count = local.mode_alb ? 1 : 0

  name               = "${var.name_prefix}-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [local.net.internal_alb_security_group_id]
  subnets            = local.net.private_subnet_ids

  tags = {
    Name = "${var.name_prefix}-internal"
  }
}

resource "aws_lb_target_group" "internal" {
  count = local.mode_alb ? 1 : 0

  name     = "${var.name_prefix}-internal"
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.net.vpc_id

  health_check {
    path = "/"
  }

  tags = {
    Name = "${var.name_prefix}-internal"
  }
}

resource "aws_lb_listener" "internal_https" {
  count = local.mode_alb ? 1 : 0

  load_balancer_arn = aws_lb.internal[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.private[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal[0].arn
  }
}

resource "aws_lb_target_group_attachment" "internal" {
  count = local.mode_alb ? 1 : 0

  target_group_arn = aws_lb_target_group.internal[0].arn
  target_id        = aws_instance.private_web.id
  port             = 80
}

resource "aws_route53_record" "private_alb" {
  count = local.mode_alb ? 1 : 0

  zone_id = aws_route53_zone.private.zone_id
  name    = var.private_hostname
  type    = "A"

  alias {
    name                   = aws_lb.internal[0].dns_name
    zone_id                = aws_lb.internal[0].zone_id
    evaluate_target_health = true
  }
}

# ---------------------------------------------------------------------------
# nginx_export (optional): PCA leaf → Secrets Manager → State Manager → nginx
# ---------------------------------------------------------------------------

resource "tls_private_key" "private_leaf" {
  count = local.mode_nginx ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "private_leaf" {
  count = local.mode_nginx ? 1 : 0

  private_key_pem = tls_private_key.private_leaf[0].private_key_pem

  subject {
    common_name = var.private_hostname
  }

  dns_names = [var.private_hostname]
}

resource "aws_acmpca_certificate" "private_leaf" {
  count = local.mode_nginx ? 1 : 0

  certificate_authority_arn   = aws_acmpca_certificate_authority.root.arn
  certificate_signing_request = tls_cert_request.private_leaf[0].cert_request_pem
  signing_algorithm           = "SHA256WITHRSA"

  template_arn = "arn:${data.aws_partition.current.partition}:acm-pca:::template/EndEntityCertificate/V1"

  validity {
    type  = "DAYS"
    value = 90
  }

  depends_on = [aws_acmpca_certificate_authority_certificate.root]
}

resource "aws_secretsmanager_secret" "private_leaf" {
  count = local.mode_nginx ? 1 : 0

  name_prefix             = "${var.name_prefix}-private-leaf-"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.name_prefix}-private-leaf"
  }
}

resource "aws_secretsmanager_secret_version" "private_leaf" {
  count = local.mode_nginx ? 1 : 0

  secret_id = aws_secretsmanager_secret.private_leaf[0].id
  secret_string = jsonencode({
    certificate = aws_acmpca_certificate.private_leaf[0].certificate
    chain       = aws_acmpca_certificate.private_leaf[0].certificate_chain
    private_key = tls_private_key.private_leaf[0].private_key_pem
  })
}

data "aws_iam_policy_document" "private_web_secrets" {
  count = local.mode_nginx ? 1 : 0

  statement {
    sid       = "ReadLeafSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.private_leaf[0].arn]
  }
}

resource "aws_iam_role_policy" "private_web_secrets" {
  count = local.mode_nginx ? 1 : 0

  name   = "read-leaf-secret"
  role   = aws_iam_role.private_web.id
  policy = data.aws_iam_policy_document.private_web_secrets[0].json
}

resource "aws_ssm_document" "configure_private_web" {
  count = local.mode_nginx ? 1 : 0

  name            = "${var.name_prefix}-configure-private-web"
  document_type   = "Command"
  document_format = "YAML"

  content = <<-DOC
    schemaVersion: "2.2"
    description: Install nginx and Private CA leaf material from Secrets Manager on private-web.
    parameters:
      SecretId:
        type: String
      Region:
        type: String
      Hostname:
        type: String
      LeafVersion:
        type: String
        description: Unused by the script; changing it forces State Manager to re-apply after leaf rotation.
      ScriptBase64:
        type: String
        description: Base64-encoded configure-private-web.sh from the repo.
    mainSteps:
      - action: aws:runShellScript
        name: ConfigurePrivateWeb
        inputs:
          runCommand:
            - |
              set -euxo pipefail
              export SECRET_ID="{{SecretId}}"
              export AWS_DEFAULT_REGION="{{Region}}"
              export PRIVATE_HOSTNAME="{{Hostname}}"
              # LeafVersion={{LeafVersion}}
              echo "{{ScriptBase64}}" | base64 -d >/tmp/configure-private-web.sh
              chmod +x /tmp/configure-private-web.sh
              /tmp/configure-private-web.sh
  DOC
}

resource "aws_ssm_association" "configure_private_web" {
  count = local.mode_nginx ? 1 : 0

  name = aws_ssm_document.configure_private_web[0].name

  targets {
    key    = "tag:LabRole"
    values = ["private-web"]
  }

  parameters = {
    SecretId     = aws_secretsmanager_secret.private_leaf[0].id
    Region       = var.aws_region
    Hostname     = var.private_hostname
    LeafVersion  = aws_secretsmanager_secret_version.private_leaf[0].version_id
    ScriptBase64 = base64encode(local.configure_private_web_script)
  }

  compliance_severity = "MEDIUM"

  depends_on = [
    aws_instance.private_web,
    aws_secretsmanager_secret_version.private_leaf,
  ]
}

resource "aws_route53_record" "private_instance" {
  count = local.mode_nginx ? 1 : 0

  zone_id = aws_route53_zone.private.zone_id
  name    = var.private_hostname
  type    = "A"
  ttl     = 60
  records = [aws_instance.private_web.private_ip]
}

# ---------------------------------------------------------------------------
# Shared: private-web instance (HTTP backend or nginx TLS target)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "private_web" {
  name_prefix        = "${var.name_prefix}-private-web-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "private_web_ssm" {
  role       = aws_iam_role.private_web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "private_web" {
  name_prefix = "${var.name_prefix}-private-web-"
  role        = aws_iam_role.private_web.name
}

resource "aws_instance" "private_web" {
  ami                    = local.net.ami_id
  instance_type          = var.instance_type
  subnet_id              = local.net.private_subnet_ids[0]
  vpc_security_group_ids = [local.net.private_web_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.private_web.name
  # alb_acm: HTTP userdata; nginx_export: null (SSM installs TLS). Replace on mode switch.
  user_data                   = local.mode_alb ? local.private_web_http_userdata : null
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = "${var.name_prefix}-private-web"
    LabRole = "private-web"
  }
}
