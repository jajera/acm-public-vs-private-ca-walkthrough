---
title: Reference
layout: default
parent: Operate
nav_order: 4
description: >-
  Repo map, staged Terraform outputs, and prove-script cheat sheet.
---

# Reference

## Repository map

| Path | Purpose |
| --- | --- |
| `terraform/01-network` | VPC, subnets, SGs, base SSM profile |
| `terraform/02-public` | ACM public, ALB, `public-web` |
| `terraform/03-private` | Private CA; ACM private + internal ALB (`alb_acm`) or leaf secret + nginx (`nginx_export`) |
| `terraform/04-trust` | S3 CA PEM, SSM association, clients |
| `scripts/install-ca-trust.sh` | Idempotent CA install used by SSM |
| `scripts/prove-*.sh` | Per-stage validation helpers |
| `docs/` | This site |

## Terraform outputs by stage

### `01-network`

| Output | Meaning |
| --- | --- |
| `vpc_id` | Lab VPC |
| `public_subnet_ids` | Two public subnets (ALB, NAT) |
| `private_subnet_ids` | Two private subnets (EC2) |
| `nat_gateway_id` / `internet_gateway_id` | Egress / ingress edge |
| `*_security_group_id` | ALB / web / clients SGs |
| `ssm_instance_profile_name` | Shared SSM profile |
| `ami_id` | Amazon Linux 2023 AMI |

### `02-public`

Creates ACM DNS validation CNAMEs and an alias A for `public_hostname` in
`route53_zone_id` (same-account public zone).

| Output | Meaning |
| --- | --- |
| `public_url` | `https://demo.johna.kiwi` |
| `public_certificate_arn` | ACM public cert |
| `alb_dns_name` | ALB DNS |
| `public_web_instance_id` | Backend instance |

### `03-private`

| Output | Meaning |
| --- | --- |
| `private_url` | `https://app.internal.johna.kiwi` |
| `private_ca_arn` | Private CA (billable) |
| `ca_certificate_pem` | Root CA PEM (for stage 4) |
| `private_tls_mode` | `alb_acm` or `nginx_export` |
| `acm_private_certificate_arn` | ACM private cert (`alb_acm`) |
| `internal_alb_dns_name` | Internal ALB DNS (`alb_acm`) |
| `private_web_private_ip` | `private-web` private IP |
| `private_leaf_secret_arn` | Secrets Manager leaf (`nginx_export`) |
| `ssm_configure_association_id` | State Manager leaf association (`nginx_export`) |
| `private_hosted_zone_id` | VPC private zone for `internal.johna.kiwi` |

### `04-trust`

| Output | Meaning |
| --- | --- |
| `ca_s3_uri` | Published CA PEM |
| `managed_client_instance_id` | SSM prove target |
| `unmanaged_client_instance_id` | Contrast host |
| `ssm_association_id` | Trust distribution association |

## Prove scripts

| Script | Stage | Expect |
| --- | --- | --- |
| `prove-network.sh` | after 01 | VPC/subnets/IGW/NAT/routes/SGs OK |
| `prove-public.sh` | after 02 | HTTPS OK, Amazon issuer |
| `prove-private-tls.sh` | after 03 | CA ACTIVE; ACM private on ALB or nginx leaf (by mode) |
| `prove-private-untrusted.sh` | after 04 | unmanaged TLS fail (no CA install) |
| `prove-private-managed.sh` | after 04 | plain `curl` OK (CA via S3 + State Manager) |

## AWS documentation

- [What is AWS Certificate Manager?](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html)
- [AWS Private CA User Guide](https://docs.aws.amazon.com/privateca/latest/userguide/PcaWelcome.html)
- [Services integrated with ACM](https://docs.aws.amazon.com/acm/latest/userguide/acm-services.html)
- [SSM State Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-state.html)
