---
inclusion: always
---

# Terraform stack

## Layout

Staged roots (not one monolith apply):

| Path | Concern |
| --- | --- |
| `01-network` | VPC, public/private subnets, IGW, NAT, SGs, base SSM profile, AMI |
| `02-public` | ACM public + same-account Route 53 validation/alias, ALB, public-web |
| `03-private` | Private CA ROOT; ACM private + internal ALB (`alb_acm`) or Secrets Manager + nginx (`nginx_export`); private DNS |
| `04-trust` | S3 CA PEM, install script, private-subnet clients, SSM association |

Cross-stage wiring: `data.terraform_remote_state` → local `../NN-*/terraform.tfstate`.

Shared operator config: `terraform/terraform.tfvars` + `-var-file=../terraform.tfvars`.

## Provider pins

| Provider | Constraint | Stages |
| --- | --- | --- |
| `hashicorp/aws` | `~> 6.68` | all |
| `hashicorp/tls` | `~> 4.4` | `03-private` |
| `hashicorp/random` | `~> 3.9` | `04-trust` |

Declare only providers each stage uses. Refresh locks with `terraform init -upgrade`.

## Conventions

- `terraform fmt -recursive` before commit
- Tag resources with project name + `ManagedBy=terraform` (+ `Stage` via provider default_tags)
- Prefer data sources for AMI / caller identity / partition
- Local state per stage for the lab; no remote backend unless asked
- Variables: domain, hosted zone, Region, name prefix — declare the full set in each
  stage so one tfvars file works

## Apply / destroy

Agents: only with `ACM_LAB_ALLOW_AWS=1`. Operators follow `docs/walkthrough.md`
(apply → verify per stage).

Destroy: `04` → `03` → `02` → `01`. Warn if destroy leaves a billable CA.
