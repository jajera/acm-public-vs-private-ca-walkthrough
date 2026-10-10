---
title: Concepts
layout: default
parent: Learn
nav_order: 2
description: >-
  Trust models, where private keys live, exportability, and cost shape for ACM
  public vs Private CA.
---

# Concepts

<span class="svc-pair">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="AWS Certificate Manager" width="48" height="48" loading="lazy">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Private-Certificate-Authority_64.svg" alt="AWS Private Certificate Authority" width="48" height="48" loading="lazy">
</span>

Public and private certificates both ride X.509, but they differ on one axis:
**who already trusts the issuer.** That single difference drives key location,
cost, and how clients behave.

## Trust models

| Model | Issuer | Client behaviour |
| --- | --- | --- |
| Public ACM | Amazon public CA | Trusted out of the box |
| Private CA | Your CA | Trust only after CA PEM is in the system store |
| Imported | Third-party CA | Trusted if that CA is already public, or if you distributed it |

Private CA does **not** mean “no trust.” It means **you operate trust**.

## Where the private key lives

| Certificate type | Typical private key location |
| --- | --- |
| ACM public (classic) | Inside ACM; ALB/CloudFront uses it |
| Private CA leaf (default) | **ACM private certificate** attached to an internal ALB |
| Private CA leaf (`nginx_export`) | Issued into **Secrets Manager**, applied by State Manager on nginx |
| CA trust anchor on clients | **Public CA certificate only** — never the CA private key |

## Exportability

- **Public ACM (classic)** → bound to integrated services (ALB, CloudFront, API
  Gateway); the key stays in ACM. This lab's public path uses this model.
- **Public ACM (exportable)** → ACM can also issue an [exportable public
  certificate](https://docs.aws.amazon.com/acm/latest/APIReference/API_ExportCertificate.html)
  whose encrypted private key you retrieve for use anywhere. Not used here — the
  ALB path needs no PEM on the instance.
- **Private CA** → default path (`alb_acm`) keeps the leaf in ACM on an internal
  ALB (HTTP backend only). Optional `nginx_export` puts leaf + key on
  `private-web` via Secrets Manager and State Manager.

## Cost shape

| Item | Shape |
| --- | --- |
| ACM public (integrated) | $0 — FQDN or wildcard |
| Private CA | Monthly CA (pro-rated) + per issued certificate |
| ALB / EC2 | Hourly while running |

ACM public [adds no charge beyond the AWS resources that use the certificate](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html).
Private CA is [charged monthly from creation until deletion](https://docs.aws.amazon.com/privateca/latest/userguide/PcaWelcome.html),
plus a fee per issued certificate. Details: [Cost]({{ site.baseurl }}/cost/).

{: .cost }
> Destroy the Private CA in the [walkthrough teardown]({{ site.baseurl }}/walkthrough/#5-teardown-reverse-order)
> (stage 3 creates it; destroy stages 4 → 3 → 2 → 1).

## DNS validation vs private issuance

- Public ACM needs [proof of domain control](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)
  (this lab uses Route 53 DNS validation for `demo.johna.kiwi`). The same CNAME
  that validates the domain also lets ACM renew the certificate automatically.
  Validation CNAMEs must live in a **publicly hosted zone** — a private hosted
  zone alone is not enough.
- For a public ACM cert on a name that should not resolve on the internet, use
  **split-horizon DNS**: validation CNAME in the public zone; app A/alias only
  in the private zone. Diagram and comparison:
  [Architecture — split-horizon]({{ site.baseurl }}/architecture/#split-horizon-dns-public-acm-on-an-internal-name)
  (not built in this lab).
- Private CA issuance needs **no** public validation — you already own the CA.
  DNS still matters so clients can **resolve** `app.internal.johna.kiwi` to
  the server.

Next: [Architecture]({{ site.baseurl }}/architecture/).
