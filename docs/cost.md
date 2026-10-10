---
title: Cost
layout: default
parent: Operate
nav_order: 2
description: >-
  ACM public pricing, Private CA monthly and issuance fees, wildcards, and
  renewal conditions — from AWS sources.
---

# Cost

Source of truth:

- [ACM pricing](https://aws.amazon.com/certificate-manager/pricing/)
- [Private CA pricing](https://aws.amazon.com/private-ca/pricing/)
- [Private CA User Guide — pricing](https://docs.aws.amazon.com/privateca/latest/userguide/PcaWelcome.html)
- [ACM DNS managed renewal](https://docs.aws.amazon.com/acm/latest/userguide/dns-renewal-validation.html)

## This lab

| Component | Charge |
| --- | --- |
| ACM public cert on the ALB | $0 (non-exportable public cert, ACM-integrated service) |
| Private CA | Monthly CA fee + per issued certificate |
| NAT Gateway | Hourly + data processing (private-subnet egress) |
| ALB | Hourly + LCU |
| EC2 × 4 | Hourly |
| Secrets Manager, S3, SSM | Low at lab scale |

{: .cost }
> Tear down after the prove steps. Private CA is monthly and pro-rated; NAT Gateway
> keeps billing hourly until stage 01 is destroyed.

## Private CA

| Item | Price (USD) |
| --- | --- |
| General-purpose CA | $400 / CA / month |
| Short-lived CA (issued certs ≤ 7 days) | $50 / CA / month |
| General-purpose issuance (1–1,000 certs / Region / month) | $0.75 / cert |
| Short-lived issuance | $0.058 / cert |

CA operation is **pro-rated** for partial months ([pricing page](https://aws.amazon.com/private-ca/pricing/)). No CA operation charge after delete. Restoring a deleted CA bills the deleted interval.

This lab uses a **general-purpose** CA. One day up, then destroy (~1/30 month):

| Line | Estimate |
| --- | --- |
| CA operation | ~$13 |
| Issuance (CA install cert; see modes below) | $0–~$1.50 |
| Public ALB + internal ALB + EC2 | Hours used |

**30-day trial:** first Private CA in the account in each Region — no **CA operation** charge for 30 days; issuance fees still apply ([pricing page](https://aws.amazon.com/private-ca/pricing/)).

Private certificates whose private key you cannot access (ACM → ELB / CloudFront / API Gateway) are **not** charged issuance ([User Guide](https://docs.aws.amazon.com/privateca/latest/userguide/PcaWelcome.html)).

| Mode | Leaf issuance |
| --- | --- |
| `alb_acm` (default) | ACM private cert on internal ALB only — typically **$0** issuance |
| `nginx_export` | Key accessible in Secrets Manager — issuance applies (~$0.75/cert tier) |

## `a.b.c` vs `*.b.c`

### ACM public (non-exportable, integrated services)

| Names on the cert | Price |
| --- | --- |
| FQDN only | $0 |
| Wildcard only | $0 |
| FQDN + wildcard SANs | $0 |

ACM pricing lists one line: public non-exportable = no cost. No FQDN/wildcard split for that product.

Exportable public and ACME public certs are different products: wildcards cost more than FQDNs ([ACM pricing](https://aws.amazon.com/certificate-manager/pricing/)). This lab does not use them.

### Private CA

| What you issue | Price |
| --- | --- |
| One cert: `app.internal.example.com` | One issuance fee |
| One cert: `*.internal.example.com` | One issuance fee (same tiers) |
| Two certs: two FQDNs | Two issuance fees |

Private CA prices **certificates issued**, not name shape. No wildcard surcharge on the Private CA pricing table.

## Renewal

### ACM public (this lab)

ACM **managed renewal** renews DNS-validated public certificates when, near expiry:

1. The certificate is in use by an AWS service, and  
2. All ACM DNS CNAME validation records are still publicly resolvable  

([DNS renewal docs](https://docs.aws.amazon.com/acm/latest/userguide/dns-renewal-validation.html)).

Imported certificates are not renewed by ACM. You replace them.

### Private CA (this lab)

**`alb_acm` (default):** ACM manages the private certificate on the internal ALB
(renewal with CA permission). No export; no Secrets Manager leaf.

**`nginx_export`:** leaves in Secrets Manager are not renewed by ACM. Re-issue
the leaf, update the secret; State Manager re-applies when the secret version id
changes (`LeafVersion` parameter).
