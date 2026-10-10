---
inclusion: always
---

# Tech

## Cloud

- Region default: `ap-southeast-2` (override via `terraform.tfvars`).
- ACM public certificate Region must match the ALB Region.
- Tools: **Terraform >= 1.5** for infra; **AWS CLI v2** for prove scripts / SSM.
- Services: ACM, ACM Private CA, ELBv2, EC2, VPC, Route 53, S3, SSM, Secrets Manager, IAM.

## Lab topology

| Host | Role |
| --- | --- |
| Public ALB + `public-web` EC2 | ACM public HTTPS → HTTP nginx |
| Internal ALB + `private-web` EC2 | ACM private HTTPS → HTTP nginx (default `alb_acm`) |
| `private-web` EC2 (`nginx_export`) | nginx HTTPS with Private CA leaf from Secrets Manager |
| `client-managed` | Tag `TrustCA=intranet`; SSM installs CA |
| `client-unmanaged` | Contrast; expect TLS failure |

## Docs site

- **Jekyll + just-the-docs** under `docs/`.
- Live site: `https://acm-public-vs-private-ca-walkthrough.johna.kiwi/`
- Local: `./scripts/docs-serve.sh`

## Repo layout

| Path | Purpose |
| --- | --- |
| `terraform/01-network` … `04-trust` | Staged lab roots (local remote_state) |
| `scripts/` | `prove-*`, `install-ca-trust.sh`, `docs-serve.sh` |
| `docs/` | just-the-docs site |
| `.kiro/` | Steering, hooks |
| `.cursor/rules/` | Cursor project rules |

## Scripts

Prove helpers are OK. Do not hide `terraform apply` behind a wrapper that agents run.
