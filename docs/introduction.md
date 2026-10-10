---
title: Introduction
layout: default
parent: Learn
nav_order: 1
description: >-
  What ACM public certificates and AWS Private CA each do, and how this lab
  uses both.
---

# Introduction

TLS certificates prove identity and encrypt traffic. On AWS you usually meet two
managed pieces: **AWS Certificate Manager (ACM)** and **AWS Private CA**. Both
issue X.509 certificates. They solve different problems.

## AWS Certificate Manager (public certificates)

<img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="AWS Certificate Manager" width="48" height="48" loading="lazy">

ACM issues **publicly trusted** certificates for names you prove you control
(this lab: DNS validation).

- Attach them to **ACM-integrated** services: Application Load Balancer,
  CloudFront, API Gateway, and others.
- Browsers and OSes trust them by default.
- Non-exportable public certificates for those integrated services are **$0**
  ([ACM pricing](https://aws.amazon.com/certificate-manager/pricing/)).
- The private key stays in ACM. TLS terminates on the load balancer (or
  CloudFront), not on an EC2 nginx process.
- **Managed renewal:** for DNS-validated public certs, ACM renews when the cert
  is in use by an AWS service and the validation CNAMEs remain in public DNS
  ([docs](https://docs.aws.amazon.com/acm/latest/userguide/dns-renewal-validation.html)).
  Imported certificates are not renewed by ACM.

Use ACM public when the endpoint is on the **public internet** and clients
should get a normal padlock with no CA install.

## AWS Private CA

<img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Private-Certificate-Authority_64.svg" alt="AWS Private Certificate Authority" width="48" height="48" loading="lazy">

Private CA is a **managed private certificate authority**. You create a CA and
issue certificates for **internal** hostnames and services.

- Certificates are not in public trust stores. Clients trust them only after you
  install the CA (this lab: Linux + SSM).
- Prefer ACM private certificates on ALB (or other ACM-integrated services) when
  you can — this lab’s default private path.
- You can also put leaves on servers that are not ACM-integrated (nginx, custom
  apps) — this lab’s optional `nginx_export` mode.
- You pay a **monthly CA fee** (pro-rated) plus **per issued certificate** when
  the key is accessible ([Private CA pricing](https://aws.amazon.com/private-ca/pricing/)).
  ACM private certs used only on integrated services typically have **no**
  issuance charge.

Use Private CA for **intranet** names, custom PKI policy, or certs on hosts ACM
cannot terminate for.

## How they work together

<div class="svc-flow">
  <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="AWS Certificate Manager" width="44" height="44" loading="lazy">
  <img src="https://aws-icons.johna.kiwi/icons/resource/networking/Res_Elastic-Load-Balancing_Application-Load-Balancer_48.svg" alt="Application Load Balancer" width="44" height="44" loading="lazy">
  <span class="svc-flow__sep">·</span>
  <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Private-Certificate-Authority_64.svg" alt="AWS Private Certificate Authority" width="44" height="44" loading="lazy">
  <img src="https://aws-icons.johna.kiwi/icons/resource/compute/Res_Amazon-EC2_Instance_48.svg" alt="Amazon EC2 running nginx" width="44" height="44" loading="lazy">
  <span class="svc-flow__sep">·</span>
  <img src="https://aws-icons.johna.kiwi/icons/resource/storage/Res_Amazon-Simple-Storage-Service_Bucket_48.svg" alt="Amazon S3 bucket" width="44" height="44" loading="lazy">
  <img src="https://aws-icons.johna.kiwi/icons/resource/management/Res_AWS-Systems-Manager_State-Manager_48.svg" alt="AWS Systems Manager State Manager" width="44" height="44" loading="lazy">
</div>

1. Public website / API → **ACM public** on ALB or CloudFront.
2. Internal apps → **Private CA** leaves, CA distributed to managed Linux fleets.
3. Third-party public cert → **import into ACM** for ALB/CloudFront (no ACM
   managed renewal).

Same domain family (`johna.kiwi`) can appear in both paths. The difference is
who trusts the issuer.

## What this lab proves

| Path | Name | Trust |
| --- | --- | --- |
| Public | `demo.johna.kiwi` | Default browser / OS trust |
| Private | `app.internal.johna.kiwi` | Only after CA install on the client |
| Managed Linux client | SSM installs CA from S3 | `curl` succeeds without `--cacert` |
| Unmanaged Linux client | No CA install | `curl` fails (untrusted issuer) |

Next: [Concepts]({{ site.baseurl }}/concepts/).
