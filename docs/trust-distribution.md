---
title: Trust distribution
layout: default
parent: Deploy
nav_order: 2
description: >-
  Publish a Private CA PEM to hardened S3 and install it on tagged Linux hosts
  with SSM State Manager — separate from leaf key material.
---

# Trust distribution
{: .no_toc }

<span class="svc-pair">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Private-Certificate-Authority_64.svg" alt="AWS Private Certificate Authority" width="48" height="48" loading="lazy">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/resource/storage/Res_Amazon-Simple-Storage-Service_Bucket_48.svg" alt="Amazon S3" width="48" height="48" loading="lazy">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/resource/management/Res_AWS-Systems-Manager_State-Manager_48.svg" alt="AWS Systems Manager State Manager" width="48" height="48" loading="lazy">
</span>

Issuing a Private CA leaf is easy. Making a Linux fleet trust your CA — safely
and repeatedly — is the operational work this lab centres on.
{: .fs-5 .fw-300 }

## On this page
{: .no_toc .text-delta }

- TOC
{:toc}

---

## What you are distributing

Only the **CA certificate** (trust anchor). Never the CA private key, and never
the server leaf private key, onto clients.

{% include diagrams/trust-split.html %}

| Material | Destination | Clients |
| --- | --- | --- |
| CA PEM | S3 → SSM → system trust store | Managed hosts only |
| Leaf (`alb_acm`, default) | ACM → internal ALB | Not on clients |
| Leaf + key (`nginx_export`) | Secrets Manager → State Manager → `private-web` | Not on clients |

Client trust is the same for both server modes. ACM holding a private cert does
**not** install the CA on clients. An ALB [trust store](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/mutual-authentication.html)
is for **mTLS** (ALB verifying client certs) — the opposite direction.

That split is also drawn on [Architecture]({{ site.baseurl }}/architecture/#trust-vs-leaf-one-line).

## Pipeline

{% include diagrams/trust-pipeline.html %}

1. **Issue** — Private CA becomes the trust anchor.
2. **Publish** — Put the CA PEM (and the install script) in a hardened S3 bucket.
3. **Target** — Tag hosts that should trust it (`TrustCA=intranet`).
4. **Distribute** — SSM State Manager runs the install as desired state.
5. **Verify** — `curl` / OpenSSL against the private hostname **without** `--cacert`.
6. **Rotate** — Overlap old and new CA PEMs before removing the old anchor.

## Do and don't

<div class="path-grid">
  <div class="path-card">
    <span class="path-card__label">Do</span>
    <strong>CA PEM, system store, tags</strong>
    <p>Private, encrypted, versioned S3 (account Block Public Access). Least-privilege <code>s3:GetObject</code> on that object. Install into the system trust store. Idempotent script. Separate leaf renewal from CA trust.</p>
  </div>
  <div class="path-card">
    <span class="path-card__label path-card__label--warn">Don't</span>
    <strong>Bypass or hand-paste</strong>
    <p>No SSH PEM pastes. No forever CA baked into an AMI with no update path. No CA or leaf private keys on clients. Do not call the managed path “proven” with <code>curl --cacert</code> — that skips the trust store.</p>
  </div>
</div>

{: .avoid }
> Success for the managed client is TLS that works **because** the CA is in the
> system store. `--cacert` proves the PEM file, not fleet trust.

## Lab mechanism

Terraform always wires **CA trust** on clients (stage 04). Server leaf handling
depends on `private_tls_mode`.

### Default leaf: ACM on internal ALB (`alb_acm`)

| Piece | What it does |
| --- | --- |
| ACM private certificate | Issued from the lab Private CA; ARN on the internal ALB HTTPS listener |
| Internal ALB | VPC-only HTTPS; HTTP target group → `private-web` |
| `private-web` | HTTP nginx only — no leaf material on the instance |

### Optional leaf: nginx export (`nginx_export`)

State Manager association on `LabRole=private-web` (not used in `alb_acm` mode).
No EC2 user data for certificate material.

| Piece | What it does |
| --- | --- |
| Secrets Manager | JSON leaf (`certificate`, `chain`, `private_key`) |
| `scripts/configure-private-web.sh` | Idempotent: install nginx, pull secret, write `/etc/nginx/ssl/`, restart |
| SSM document | Decode script, set env, run configure |
| SSM association | Targets tag `LabRole=private-web`; `LeafVersion` forces re-apply on rotation |
| `private-web` | Instance profile may `secretsmanager:GetSecretValue` on that secret only |

### CA trust on managed clients (stage 04)

| Piece | What it does |
| --- | --- |
| S3 bucket | SSE-S3, versioning, deny insecure transport (account BPA) |
| `trust/ca.pem` | Root CA certificate from ACM Private CA |
| `trust/install-ca-trust.sh` | Idempotent install script (same file as `scripts/install-ca-trust.sh`) |
| SSM document | `aws s3 cp` the script, then run it with the CA S3 URI |
| SSM association | Targets tag `TrustCA=intranet`; `schedule_expression = rate(30 minutes)` |
| `client-managed` | Tagged `TrustCA=intranet`; instance profile may `s3:GetObject` on the trust prefix |
| `client-unmanaged` | Same AMI, VPC, and SG; **only difference is no trust tag** — association never targets it |

**When vs what:** State Manager owns the cadence (create, tag change, and the
30-minute schedule). The script does not sleep or cron — it only installs when
the PEM SHA-256 changed.

### Install script behaviour

`scripts/install-ca-trust.sh`:

1. Fetch PEM from `s3://…` (or a local path).
2. Require a `BEGIN CERTIFICATE` block.
3. Compare SHA-256 to `/etc/pki/ca-trust/source/anchors/intranet-private-ca.pem`.
4. If unchanged, exit 0; otherwise install and run `update-ca-trust extract`.

### Prove contrast

| Client | System trust | Private HTTPS |
| --- | --- | --- |
| Managed | CA installed by SSM | Succeeds without `--cacert` |
| Unmanaged | Default Amazon Linux store | Fails (untrusted issuer) |

Fair contrast: same AMI and security group; only the `TrustCA` tag differs.
Run both from the [walkthrough]({{ site.baseurl }}/walkthrough/) prove scripts.

## Distro commands

This lab uses **Amazon Linux 2023**. Same idea elsewhere:

| Family | Anchor location | Refresh |
| --- | --- | --- |
| Amazon Linux / RHEL | `/etc/pki/ca-trust/source/anchors/` | `update-ca-trust extract` |
| Debian / Ubuntu | `/usr/local/share/ca-certificates/*.crt` | `update-ca-certificates` |

## Rotation (overlap)

1. Publish the new CA PEM (new object version, or a second anchor file for overlap).
2. Wait for the **scheduled** association (or force a re-run) — hosts with a
   changed SHA-256 install the new anchor; unchanged hosts no-op.
3. Re-issue leaves from the new CA; cut traffic over.
4. Remove the old CA from anchors after the overlap window.

Leaf renewal (new server cert, same CA) is a **different** pipeline from CA
replacement. Keep them separate so a leaf rollover does not require touching
every client.

## Where next

| Topic | Page |
| --- | --- |
| Topology and host roles | [Architecture]({{ site.baseurl }}/architecture/) |
| Apply and prove | [Walkthrough]({{ site.baseurl }}/walkthrough/) |
| When to use Private CA | [Usage guide]({{ site.baseurl }}/usage-guide/) |

Next: [Walkthrough]({{ site.baseurl }}/walkthrough/).
