---
title: Architecture
layout: default
parent: Deploy
nav_order: 1
description: >-
  One VPC with public and private subnets (IGW + NAT), an ACM public ALB path,
  a Private CA internal-ALB path (optional nginx export), S3 + SSM Linux CA
  trust distribution, and split-horizon DNS for public ACM (docs only).
---

# Architecture
{: .no_toc }

One VPC with public and private subnets, two TLS stories, four Linux hosts —
public trust on the ALB, private trust you install yourself.
{: .fs-5 .fw-300 }

## On this page
{: .no_toc .text-delta }

- TOC
{:toc}

---

## Topology

{% include diagrams/architecture-topology.html %}

## Network tiers

| Tier | Contents | Edge |
| --- | --- | --- |
| Public subnets (×2 AZs) | Public ALB, NAT Gateway | IGW for inbound internet → public ALB |
| Private subnets (×2 AZs) | Internal ALB (default private path), `public-web`, `private-web`, both clients | Egress via single NAT (lab, not HA) |

| Host | Subnet | Role | Expectation |
| --- | --- | --- | --- |
| Public ALB | Public | HTTPS edge + ACM public | Internet reaches `demo.johna.kiwi` |
| Internal ALB | Private | HTTPS edge + ACM private (default) | VPC reaches `app.internal.johna.kiwi` |
| `public-web` | Private | Public ALB HTTP target | No public IP |
| `private-web` | Private | Internal ALB HTTP target (default) or nginx TLS (`nginx_export`) | Private DNS |
| `client-managed` | Private | Tag `TrustCA=intranet` | Private URL works without `--cacert` |
| `client-unmanaged` | Private | No trust tag | Private URL fails (untrusted issuer) |

<div class="path-grid">
  <a class="path-card" href="#public-path">
    <span class="path-card__label">Public</span>
    <span class="path-card__icons">
      <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="" width="40" height="40" loading="lazy">
      <img src="https://aws-icons.johna.kiwi/icons/resource/networking/Res_Elastic-Load-Balancing_Application-Load-Balancer_48.svg" alt="" width="40" height="40" loading="lazy">
    </span>
    <strong>ALB + ACM public</strong>
    <p>TLS ends on the load balancer. Backend stays HTTP.</p>
    <span class="path-card__meta">demo.johna.kiwi</span>
  </a>
  <a class="path-card" href="#private-path">
    <span class="path-card__label">Private</span>
    <span class="path-card__icons">
      <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Private-Certificate-Authority_64.svg" alt="" width="40" height="40" loading="lazy">
      <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="" width="40" height="40" loading="lazy">
    </span>
    <strong>Internal ALB + ACM private</strong>
    <p>Default: same ALB pattern, Private CA via ACM. Optional nginx export mode.</p>
    <span class="path-card__meta">app.internal.johna.kiwi</span>
  </a>
  <a class="path-card" href="{{ site.baseurl }}/trust-distribution/">
    <span class="path-card__label path-card__label--warn">Trust</span>
    <span class="path-card__icons">
      <img src="https://aws-icons.johna.kiwi/icons/resource/storage/Res_Amazon-Simple-Storage-Service_Bucket_48.svg" alt="" width="40" height="40" loading="lazy">
      <img src="https://aws-icons.johna.kiwi/icons/resource/management/Res_AWS-Systems-Manager_State-Manager_48.svg" alt="" width="40" height="40" loading="lazy">
    </span>
    <strong>S3 + SSM</strong>
    <p>CA PEM only — pipeline, do/don't, rotation.</p>
    <span class="path-card__meta">TrustCA=intranet</span>
  </a>
</div>

## Public path

<img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="AWS Certificate Manager" width="48" height="48" loading="lazy">

TLS terminates on the **Application Load Balancer**. ACM holds the public
certificate; [DNS validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)
writes CNAMEs into the existing `johna.kiwi` hosted zone. The target group speaks
**HTTP** to `public-web`.

| Piece | Lab choice |
| --- | --- |
| Certificate | ACM public, DNS-validated for `demo.johna.kiwi` |
| Listener | HTTPS `:443` → target group HTTP `:80` |
| Backend | Amazon Linux 2023 + nginx in a **private** subnet |
| Edge | ALB in **public** subnets; IGW for inbound |
| DNS | Route 53 alias to the ALB |

ACM public certificates are [trusted by major browsers and operating systems](https://docs.aws.amazon.com/acm/latest/userguide/certificate-types.html)
by default — no client-side CA install.

## Private path

<img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Private-Certificate-Authority_64.svg" alt="AWS Private Certificate Authority" width="48" height="48" loading="lazy">

Terraform creates a **ROOT** AWS Private CA. Server TLS mode is selected with
`private_tls_mode` in `terraform.tfvars` (mutually exclusive on the same hostname).
The topology diagram above shows **2a** (`alb_acm`, default) then **2b**
(`nginx_export`).

### Default: `alb_acm`

TLS terminates on an **internal ALB**. ACM requests a **private certificate** from
the lab Private CA and attaches it by ARN (same pattern as the public path).
`private-web` speaks **HTTP** only — no leaf on the instance.

| Piece | Lab choice |
| --- | --- |
| CA | ACM Private CA `ROOT`, RSA 2048, 7-day permanent deletion window |
| Leaf | ACM private cert for `app.internal.johna.kiwi` (key stays in ACM) |
| Edge | Internal ALB in **private** subnets; HTTPS `:443` from VPC CIDR |
| Backend | `private-web` nginx `:80` |
| DNS | Private hosted zone alias → internal ALB |

### Optional: `nginx_export`

TLS terminates on **nginx** on `private-web`. Terraform issues the leaf via
Private CA `IssueCertificate`, stores leaf + key in **Secrets Manager**, and SSM
State Manager (tag `LabRole=private-web`) runs `scripts/configure-private-web.sh`.

| Piece | Lab choice |
| --- | --- |
| Material | Secrets Manager JSON (`certificate`, `chain`, `private_key`) |
| Server config | State Manager → nginx + `/etc/nginx/ssl/` |
| DNS | Private hosted zone A → instance private IP |

Managed vs unmanaged clients prove client trust either way. ACM does **not**
install the CA on clients. Pipeline detail:
[Trust distribution]({{ site.baseurl }}/trust-distribution/).

## Split-horizon DNS (public ACM on an internal name)

{: .note }
> **Not built in this lab.** Architecture only — no Terraform stage or prove
> script. The lab private path uses Private CA instead.

When you want an **ACM public** certificate on a hostname that must not resolve
on the internet, use [Route 53 split-view DNS](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-considerations.html):
a **public** and a **private** hosted zone with the same name.

| Record | Zone | Purpose |
| --- | --- | --- |
| ACM DNS validation CNAME | **Public** | [ACM validators](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html) query public DNS |
| App A / alias (`x.example.internal` → internal ALB) | **Private** | VPC clients resolve the name; no public A required |

Client trust uses Amazon’s public roots — no CA PEM install. That differs from
this lab’s Private CA path (S3 + SSM).

{% include diagrams/split-horizon-acm.html %}

| Choose | When |
| --- | --- |
| Split-horizon + public ACM | Internal name, but clients should trust Amazon’s CA (no fleet CA) |
| Private CA (this lab) | You own the issuer; only managed clients should trust |

A validation CNAME that exists **only** in the private zone will not issue
([ACM troubleshooting](https://docs.aws.amazon.com/acm/latest/userguide/troubleshooting-DNS-validation.html)).

## Trust vs leaf (one line)

| Material | Goes to | Clients |
| --- | --- | --- |
| **CA PEM** | S3 → SSM → system trust | Managed only |
| **Leaf (alb_acm)** | ACM → internal ALB | Never |
| **Leaf + key (nginx_export)** | Secrets Manager → State Manager → `private-web` | Never |

Do not put CA or leaf private keys on clients. Full do/don't and rotation:
[Trust distribution]({{ site.baseurl }}/trust-distribution/).

## Names and Region

| Item | Default |
| --- | --- |
| Region | `ap-southeast-2` (ACM public cert must match the ALB Region) |
| VPC CIDR | `10.42.0.0/16` (public `/24`s + private `/24`s, IGW + NAT) |
| Public hostname | `demo.johna.kiwi` |
| Private hostname | `app.internal.johna.kiwi` |
| Private TLS mode | `alb_acm` (or `nginx_export`) |
| Public hosted zone | Same-account zone (`route53_zone_id`) — ACM validation + ALB alias |
| Private hosted zone | Created in stage 03, associated with the lab VPC |
| Name prefix | `acm-lab` |

Override in `terraform/terraform.tfvars`.

## Where next

| Topic | Page |
| --- | --- |
| S3 + SSM install pipeline | [Trust distribution]({{ site.baseurl }}/trust-distribution/) |
| Apply, prove, destroy | [Walkthrough]({{ site.baseurl }}/walkthrough/) |
| Trust models / DNS validation | [Concepts]({{ site.baseurl }}/concepts/) |
| When to use split-horizon vs Private CA | [Usage guide]({{ site.baseurl }}/usage-guide/) |
| Pricing / renewal | [Cost]({{ site.baseurl }}/cost/) |

Next: [Trust distribution]({{ site.baseurl }}/trust-distribution/).
