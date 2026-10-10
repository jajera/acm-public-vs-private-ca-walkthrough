# Terraform lab (staged)

Four roots, four states. Apply in order; destroy in reverse. Shared settings live
in `terraform.tfvars` at this directory.

| Stage | Path | Produces |
| --- | --- | --- |
| 1 | `01-network` | VPC, public/private subnets, IGW, NAT, SGs, SSM profile |
| 2 | `02-public` | ACM public + DNS validation + ALB alias + `public-web` |
| 3 | `03-private` | Private CA + leaf + `private-web` + private hosted zone |
| 4 | `04-trust` | S3 CA PEM + SSM + private-subnet prove clients |

Stages 2–4 read earlier outputs via `terraform_remote_state` (local backend paths).

## Provider pins (latest stable)

| Provider | Constraint | Notes |
| --- | --- | --- |
| `hashicorp/aws` | `~> 6.68` | All stages |
| `hashicorp/tls` | `~> 4.4` | Stage 03 only (leaf CSR) |
| `hashicorp/random` | `~> 3.9` | Stage 04 only (S3 bucket suffix) |

Locks under each stage record the exact versions (`terraform init -upgrade`).

## Configure

```bash
cp terraform.tfvars.example terraform.tfvars
# set route53_zone_id to a public hosted zone in this AWS account
```

## Apply (example: stage 1)

```bash
cd 01-network
terraform init
terraform apply -var-file=../terraform.tfvars
```

Repeat for `02-public`, `03-private`, `04-trust`. Full verify steps:
[docs/walkthrough.md](../docs/walkthrough.md).

## Destroy

```bash
cd 04-trust && terraform destroy -var-file=../terraform.tfvars
cd ../03-private && terraform destroy -var-file=../terraform.tfvars
cd ../02-public  && terraform destroy -var-file=../terraform.tfvars
cd ../01-network && terraform destroy -var-file=../terraform.tfvars
```

**Private CA bills monthly** while stage 3 exists — destroy promptly.
