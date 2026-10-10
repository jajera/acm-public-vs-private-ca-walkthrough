data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "${path.module}/../01-network/terraform.tfstate"
  }
}

data "terraform_remote_state" "private" {
  backend = "local"
  config = {
    path = "${path.module}/../03-private/terraform.tfstate"
  }
}

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
  net     = data.terraform_remote_state.network.outputs
  private = data.terraform_remote_state.private.outputs
}

resource "random_id" "ca_bucket" {
  byte_length = 4
}

resource "aws_s3_bucket" "ca_trust" {
  bucket = "${var.name_prefix}-ca-trust-${random_id.ca_bucket.hex}"

  tags = {
    Name = "${var.name_prefix}-ca-trust"
  }
}

# Bucket-level Public Access Block is omitted: this account's SCP denies
# s3:PutBucketPublicAccessBlock. Account/org Block Public Access still applies.

resource "aws_s3_bucket_versioning" "ca_trust" {
  bucket = aws_s3_bucket.ca_trust.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ca_trust" {
  bucket = aws_s3_bucket.ca_trust.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "ca_trust_tls" {
  bucket = aws_s3_bucket.ca_trust.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.ca_trust.arn,
          "${aws_s3_bucket.ca_trust.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_object" "ca_pem" {
  bucket = aws_s3_bucket.ca_trust.id
  key    = "trust/ca.pem"
  # CA cert is public trust material; marked sensitive in 03-private outputs only to
  # avoid dumping PEM in apply logs — safe to publish to the hardened trust bucket.
  content      = nonsensitive(local.private.ca_certificate_pem)
  content_type = "application/x-pem-file"
}

resource "aws_s3_object" "install_script" {
  bucket = aws_s3_bucket.ca_trust.id
  key    = "trust/install-ca-trust.sh"
  source = "${path.module}/../../scripts/install-ca-trust.sh"
  etag   = filemd5("${path.module}/../../scripts/install-ca-trust.sh")
}

resource "aws_iam_role" "managed_client" {
  name_prefix        = "${var.name_prefix}-managed-client-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "managed_client_ssm" {
  role       = aws_iam_role.managed_client.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "managed_client_ca" {
  statement {
    sid = "GetCaTrustObjects"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = [
      "${aws_s3_bucket.ca_trust.arn}/${aws_s3_object.ca_pem.key}",
      "${aws_s3_bucket.ca_trust.arn}/${aws_s3_object.install_script.key}",
    ]
  }
}

resource "aws_iam_role_policy" "managed_client_ca" {
  name   = "get-ca-pem"
  role   = aws_iam_role.managed_client.id
  policy = data.aws_iam_policy_document.managed_client_ca.json
}

resource "aws_iam_instance_profile" "managed_client" {
  name_prefix = "${var.name_prefix}-managed-client-"
  role        = aws_iam_role.managed_client.name
}

resource "aws_instance" "client_managed" {
  ami                    = local.net.ami_id
  instance_type          = var.instance_type
  subnet_id              = local.net.private_subnet_ids[1]
  vpc_security_group_ids = [local.net.clients_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.managed_client.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = "${var.name_prefix}-client-managed"
    TrustCA = "intranet"
    LabRole = "managed-client"
  }
}

resource "aws_instance" "client_unmanaged" {
  ami                    = local.net.ami_id
  instance_type          = var.instance_type
  subnet_id              = local.net.private_subnet_ids[1]
  vpc_security_group_ids = [local.net.clients_security_group_id]
  iam_instance_profile   = local.net.ssm_instance_profile_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = "${var.name_prefix}-client-unmanaged"
    LabRole = "unmanaged-client"
  }
}

resource "aws_ssm_document" "install_ca_trust" {
  name            = "${var.name_prefix}-install-ca-trust"
  document_type   = "Command"
  document_format = "YAML"

  content = <<-DOC
    schemaVersion: "2.2"
    description: Install intranet Private CA into the Amazon Linux system trust store.
    parameters:
      Bucket:
        type: String
      CaObjectKey:
        type: String
        default: trust/ca.pem
      ScriptObjectKey:
        type: String
        default: trust/install-ca-trust.sh
    mainSteps:
      - action: aws:runShellScript
        name: InstallCaTrust
        inputs:
          runCommand:
            - |
              set -euxo pipefail
              aws s3 cp "s3://{{Bucket}}/{{ScriptObjectKey}}" /tmp/install-ca-trust.sh
              chmod +x /tmp/install-ca-trust.sh
              /tmp/install-ca-trust.sh "s3://{{Bucket}}/{{CaObjectKey}}"
  DOC
}

resource "aws_ssm_association" "install_ca_trust" {
  name = aws_ssm_document.install_ca_trust.name

  targets {
    key    = "tag:TrustCA"
    values = ["intranet"]
  }

  parameters = {
    Bucket = aws_s3_bucket.ca_trust.id
  }

  # Cadence is SSM's job (min 30 minutes for associations). The install script
  # stays idempotent so re-runs are a no-op when the PEM is unchanged.
  schedule_expression = "rate(30 minutes)"

  compliance_severity = "MEDIUM"

  depends_on = [
    aws_instance.client_managed,
    aws_s3_object.ca_pem,
    aws_s3_object.install_script,
  ]
}
