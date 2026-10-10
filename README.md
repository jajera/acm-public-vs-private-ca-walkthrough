# acm-public-vs-private-ca-walkthrough

All-in-one lab: **ACM public** TLS on an internet-facing ALB and **AWS Private CA**
TLS on an **internal ALB** (ACM private cert by default), plus Linux CA trust
distribution (S3 + SSM State Manager). Optional `nginx_export` mode puts the leaf
on nginx via Secrets Manager instead. Public and private paths are complementary.

| Path | Name | What proves it |
| --- | --- | --- |
| Public ACM | `demo.johna.kiwi` | Internet ALB HTTPS; browsers trust by default |
| Private CA (default `alb_acm`) | `app.internal.johna.kiwi` | Internal ALB + ACM private cert; managed client passes |
| Private CA (optional `nginx_export`) | same hostname | nginx HTTPS from Secrets Manager + State Manager |

### Live leaf evidence (same account)

Public ACM (laptop → public ALB):

```text
subject=CN = demo.johna.kiwi
issuer=C = US, O = Amazon, CN = Amazon RSA 2048 M04
```

Private CA via ACM on internal ALB (default; issuer is the lab Private CA):

```text
subject=CN=app.internal.johna.kiwi
issuer=C=NZ, O=jajera, OU=acm-lab, CN=acm-lab Lab Root CA
```

Trusted client check (after stage 04; run on `client-managed`):

```bash
curl -fsS --max-time 15 https://app.internal.johna.kiwi/
```

Mode switch in `terraform/terraform.tfvars`: `private_tls_mode = "alb_acm"` or
`"nginx_export"`.

Default Region: `ap-southeast-2`. Needs a Route 53 **public** hosted zone in the
**same account** as the lab (`route53_zone_id`) for ACM validation and the ALB alias.

## Docs

📖 **[Published documentation site](https://acm-public-vs-private-ca-walkthrough.johna.kiwi/)** —
introduction, architecture, trust distribution, full walkthrough, usage guide.

| Doc | Purpose |
| --- | --- |
| [docs/index.md](docs/index.md) | Overview and reading order |
| [docs/introduction.md](docs/introduction.md) | What ACM and Private CA do |
| [docs/architecture.md](docs/architecture.md) | ALB paths, trust vs leaf, split-horizon (docs only) |
| [docs/trust-distribution.md](docs/trust-distribution.md) | Linux CA install best practice |
| [docs/walkthrough.md](docs/walkthrough.md) | Staged deploy, prove, destroy |
| [docs/usage-guide.md](docs/usage-guide.md) | When to use which; what to avoid |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common failures |
| [docs/reference.md](docs/reference.md) | Repo / staged Terraform outputs |

The site is built with [just-the-docs](https://just-the-docs.com/) and deploys from
`.github/workflows/docs.yml`.

### Preview docs locally

```bash
./scripts/docs-serve.sh
```

Open [http://127.0.0.1:4000/](http://127.0.0.1:4000/).

## Layout

```text
terraform/
  01-network/   # VPC + SGs (public + internal ALB)
  02-public/    # ACM public + internet ALB
  03-private/   # Private CA + ACM private internal ALB (or nginx_export)
  04-trust/     # S3 CA PEM + SSM clients
scripts/        # prove-* , configure-private-web.sh, install-ca-trust.sh
docs/           # just-the-docs site
```

## Prerequisites

- Terraform `>= 1.5`, AWS CLI v2
- Permissions for VPC, EC2, ELB, ACM, ACM PCA, S3, SSM, Secrets Manager, Route 53
- Public hosted zone ID (`route53_zone_id`)
- [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for client proves

Full step-by-step with verify after each stage: **[docs/walkthrough.md](docs/walkthrough.md)**.

## Deploy (staged)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# set route53_zone_id (same-account public zone)

cd 01-network && terraform init && terraform apply -var-file=../terraform.tfvars
cd ../02-public && terraform init && terraform apply -var-file=../terraform.tfvars
# prove public
cd ../.. && ./scripts/prove-public.sh

cd terraform/03-private && terraform init && terraform apply -var-file=../terraform.tfvars
cd ../.. && ./scripts/prove-private-tls.sh

cd terraform/04-trust && terraform init && terraform apply -var-file=../terraform.tfvars
# wait for SSM association, then:
cd ../.. && ./scripts/prove-private-untrusted.sh
./scripts/prove-private-managed.sh
```

## Destroy

Reverse order — Private CA lives in stage 3:

```bash
cd terraform/04-trust && terraform destroy -var-file=../terraform.tfvars
cd ../03-private && terraform destroy -var-file=../terraform.tfvars
cd ../02-public  && terraform destroy -var-file=../terraform.tfvars
cd ../01-network && terraform destroy -var-file=../terraform.tfvars
```

Confirm the Private CA is gone — it bills **monthly** while it exists.

## Cost note

| Item | Charge |
| --- | --- |
| ACM public on ALB | $0 (FQDN or wildcard) |
| Private CA (general-purpose) | $400/CA/month, pro-rated + $0.75/cert (first tier) |
| ALB + EC2 | Hourly while running |

Full tables: [docs/cost.md](docs/cost.md).
