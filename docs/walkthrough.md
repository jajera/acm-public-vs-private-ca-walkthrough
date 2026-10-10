---
title: Walkthrough
layout: default
parent: Deploy
nav_order: 3
description: >-
  Apply the lab in four Terraform stages — network, public ACM, Private CA,
  trust distribution — and verify after each.
---

# Walkthrough
{: .no_toc }

<span class="svc-pair">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/networking/Arch_Amazon-Virtual-Private-Cloud_64.svg" alt="Amazon VPC" width="44" height="44" loading="lazy">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="AWS Certificate Manager" width="44" height="44" loading="lazy">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Private-Certificate-Authority_64.svg" alt="AWS Private Certificate Authority" width="44" height="44" loading="lazy">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/resource/management/Res_AWS-Systems-Manager_State-Manager_48.svg" alt="AWS Systems Manager State Manager" width="44" height="44" loading="lazy">
</span>

Author commands; you run apply, prove, and destroy. The stack is **four Terraform
roots**, each with its own state. Apply in order; verify before moving on.
{: .fs-5 .fw-300 }

## On this page
{: .no_toc .text-delta }

- TOC
{:toc}

---

## Stages

{% include diagrams/stage-flow.html %}

| Stage | Directory | What it creates | Verify |
| --- | --- | --- | --- |
| 1 | `terraform/01-network` | VPC, public/private subnets, IGW, NAT, SGs, SSM profile | `prove-network.sh` |
| 2 | `terraform/02-public` | ACM public cert, ALB, `public-web`, DNS | `prove-public.sh` |
| 3 | `terraform/03-private` | Private CA + ACM private on internal ALB (default) or nginx export | `prove-private-tls.sh` |
| 4 | `terraform/04-trust` | S3 CA PEM, SSM association, both clients | untrusted fail + managed pass |

Later stages read earlier state with `terraform_remote_state` (local paths). Do not
skip ahead.

**Per-stage pattern:** apply → wait if needed → run the prove script → match the
**Verified results** sample for that stage. Resource IDs change every apply; the
`✓` checks and final `PASS` line are what matter.

{: .cost }
> Private CA starts billing when stage **3** creates it —
> [charged from creation until deletion](https://docs.aws.amazon.com/privateca/latest/userguide/PcaWelcome.html).
> Prefer finishing stage 4 and tearing down in the same session.

## Prerequisites

- AWS account with rights for VPC, EC2, ELB, ACM, ACM PCA, S3, SSM, Secrets Manager, Route 53
- AWS CLI v2 and Terraform `>= 1.5`
- Route 53 **public** hosted zone **in the same account** as the lab (set
  `route53_zone_id`) — stage 02 writes ACM validation CNAMEs and the ALB alias
- Session Manager plugin (for stage 3–4 SSM proves)
- AWS credentials for the lab account in `ap-southeast-2`

## 0. Configure once

One `terraform.tfvars` at the `terraform/` root is shared by every stage via
`-var-file=../terraform.tfvars`.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# set route53_zone_id (same-account public zone)
# optional: public_hostname, private_hostname, private_tls_mode (default alb_acm)
```

## 1. Network

```bash
cd terraform/01-network
terraform init
terraform apply -var-file=../terraform.tfvars
```

NAT Gateway creation often takes ~2 minutes. Apply finishes only after NAT is
`available` and private routes are associated.

### Verify

From the repo root:

```bash
./scripts/prove-network.sh
```

### Verified results (stage 1)

Example from a live apply (`ap-southeast-2`). Resource IDs change each apply; the
checks and `PASS` line are what matter.

```text
────────────────────────────────────────
 Stage 01 · Network
────────────────────────────────────────
  ✓ VPC CIDR (10.42.0.0/16)
    vpc_id=vpc-0a7254a13846b8b27
  ✓ Subnet 10.42.0.0/24 (public)
  ✓ Subnet 10.42.1.0/24 (public)
  ✓ Subnet 10.42.10.0/24 (private)
  ✓ Subnet 10.42.11.0/24 (private)
  ✓ Terraform outputs list 2 public + 2 private subnets
  ✓ IGW attached to lab VPC (vpc-0a7254a13846b8b27)
  ✓ NAT Gateway state (available)
  ✓ NAT sits in a public subnet
  ✓ Public default route → IGW (igw-095e7a6ceb0b13252)
  ✓ Private default route → NAT (nat-0ce99220005341549)
  ✓ Security group alb exists
  ✓ Security group public-web exists
  ✓ Security group private-web exists
  ✓ Security group clients exists

  PASS · stage 01 network looks good — continue to stage 02
```

Stage 2+ reads this state via `terraform_remote_state`.

## 2. Public ACM path

Depends on stage 1 state at `../01-network/terraform.tfstate`.

```bash
cd terraform/02-public
terraform init
terraform apply -var-file=../terraform.tfvars
```

Stage 02 creates DNS validation CNAMEs and an alias for `public_hostname` in
`route53_zone_id`, waits for ACM `ISSUED`, then attaches the cert to the ALB.
Wait until the ALB target is healthy (a minute or two after `public-web` boots).

### Verify

From the repo root:

```bash
./scripts/prove-public.sh
```

### Verified results (stage 2)

Example from a live apply:

```text
────────────────────────────────────────
 Stage 02 · Public ACM path
────────────────────────────────────────
  ✓ HTTPS response (200)
    https://demo.johna.kiwi
  ✓ Certificate issued by Amazon
  ✓ Certificate name is demo.johna.kiwi
    issuer=C = US, O = Amazon, CN = Amazon RSA 2048 M04 subject=CN = demo.johna.kiwi

  PASS · public path works with default trust — continue to stage 03
```

## 3. Private CA path

Depends on stage 1. **This stage creates the billable Private CA.**

Default mode is `private_tls_mode = "alb_acm"` in `terraform.tfvars`: ACM private
certificate on an **internal ALB**, HTTP backend on `private-web` (mirrors stage 2).

```bash
cd terraform/03-private
terraform init
terraform apply -var-file=../terraform.tfvars
```

Wait for the internal ALB target to be healthy and Session Manager to see
`private-web` online (1–2 minutes; private subnet egress via NAT).

### Verify

From the **repo root on your laptop** (same machine that ran `terraform apply`):

```bash
./scripts/prove-private-tls.sh
```

#### Where each check runs (`alb_acm`)

| Line in the output | Runs on | How |
| --- | --- | --- |
| You start the script | **Your laptop** | shell |
| Private CA / ACM status | **Your laptop** | `aws acm-pca` / `aws acm` |
| `subject=` / `issuer=` / HTTP backend | **`private-web` EC2** | SSM Run Command; OpenSSL to the private hostname (resolves to internal ALB) |

Your laptop never opens `https://app.internal.johna.kiwi`. That name only
resolves inside the VPC.

Stage 3 does **not** install the CA and does **not** use `curl -k`. Trusted
HTTPS (plain `curl` after S3 + State Manager) is stage **4**.

### Verified results (stage 3, default `alb_acm`)

```text
────────────────────────────────────────
 Stage 03 · Private CA + leaf (alb_acm)
────────────────────────────────────────
    private_tls_mode=alb_acm
  ✓ [laptop] reading terraform outputs + AWS API
  ✓ Private CA status (ACTIVE)
  ✓ ACM private cert status (ISSUED)
  ✓ [SSM → private-web] inspect ALB leaf + HTTP backend
    subject=CN=app.internal.johna.kiwi
    issuer=C=NZ, O=jajera, OU=acm-lab, CN=acm-lab Lab Root CA
    HTTP backend on private-web OK (TLS is on the internal ALB)
  ✓ Leaf served by internal ALB (ACM private cert)

  PASS · ACM private cert on internal ALB — run stage 04 for trusted client curl
```

### Optional: `nginx_export` mode

Same hostname; mutually exclusive with `alb_acm`. Set in `terraform.tfvars`:

```hcl
private_tls_mode = "nginx_export"
```

Re-apply stage 03 (and 04 if already applied). Changing `private_tls_mode`
replaces `private-web` (`user_data_replace_on_change`) so the HTTP userdata vs
SSM leaf path stays consistent. Leaf goes to Secrets Manager; State Manager
configures nginx `:443` on `private-web`. Prove script branches automatically
and checks `/etc/nginx/ssl/` instead of the ALB path.

## 4. Trust distribution

Depends on stages 1 and 3 (`ca_certificate_pem` from private state).

```bash
cd terraform/04-trust
terraform init
terraform apply -var-file=../terraform.tfvars
```

Wait for SSM State Manager to run on `client-managed` (tag `TrustCA=intranet`) —
usually 1–2 minutes after the instance is online. The association also re-runs on
a `rate(30 minutes)` schedule (desired-state drift correction); the install
script no-ops when the PEM is unchanged.

### Verify

Two clients, two outcomes. Run both from the **repo root on your laptop**:

1. **Unmanaged** (no CA in the system store) — TLS to the private URL must fail  
2. **Managed** (CA installed by S3 + State Manager) — plain `curl` must succeed  

```bash
./scripts/prove-private-untrusted.sh
./scripts/prove-private-managed.sh
```

| Script | Laptop | Remote (SSM) |
| --- | --- | --- |
| `prove-private-untrusted.sh` | starts script, reads outputs | plain `curl` on **`client-unmanaged`** |
| `prove-private-managed.sh` | starts script; checks State Manager status | plain `curl` on **`client-managed`** |

CA install (Terraform, not the prove script): S3 `trust/ca.pem` → State Manager
(tag `TrustCA=intranet`) → system trust on `client-managed`. No `curl -k`, no
`--cacert`.

### Verified results (stage 4)

Example from a live apply:

```text
────────────────────────────────────────
 Stage 04 · Unmanaged client (must fail TLS)
────────────────────────────────────────
    you are on: laptop (this script)
    curl runs on: client-unmanaged via SSM
  ✓ [SSM → client-unmanaged] plain curl (no -k, no --cacert)
    TLS rejected as expected
    curl: (60) SSL certificate OpenSSL verify result: self-signed certificate in certificate chain (19)

  PASS · unmanaged client correctly rejects the issuer — next: prove-private-managed.sh

────────────────────────────────────────
 Stage 04 · Managed client (must succeed without --cacert)
────────────────────────────────────────
    you are on: laptop (this script)
    curl runs on: client-managed via SSM
    CA install path: S3 → State Manager → system trust store
  ✓ [laptop] latest State Manager run: Success
  ✓ [SSM → client-managed] plain curl after CA install
    CA anchor present (from S3 + State Manager)
    <!DOCTYPE html>
    …
    TLS OK with system trust (no -k, no --cacert)

  PASS · managed client trusts the private path — lab complete
```

## 5. Teardown (reverse order)

Destroy **trust → private → public → network** so the Private CA goes away before
you forget.

```bash
cd terraform/04-trust && terraform destroy -var-file=../terraform.tfvars
cd ../03-private && terraform destroy -var-file=../terraform.tfvars
cd ../02-public  && terraform destroy -var-file=../terraform.tfvars
cd ../01-network && terraform destroy -var-file=../terraform.tfvars
```

Confirm in the console that the Private CA is deleted/disabled and no longer
billing.

{: .warning }
> If destroy fails on the CA, fix dependencies and retry. Do not leave an
> `ACTIVE` Private CA behind after a demo.

## Layout reminder

```text
terraform/
  terraform.tfvars          # you create (gitignored)
  01-network/               # VPC + public/private + IGW + NAT + SGs
  02-public/                # ACM + ALB + public-web
  03-private/               # Private CA + ACM private ALB (or nginx_export)
  04-trust/                 # S3 CA PEM + SSM + clients
```

Each later stage uses `terraform_remote_state` against the previous stage’s
local `terraform.tfstate`. Keep those state files on the machine that applied
them (or move the whole `terraform/` tree together).

## What next

Read the [Usage guide]({{ site.baseurl }}/usage-guide/) for when to use which
service, best practices, and what to avoid.
