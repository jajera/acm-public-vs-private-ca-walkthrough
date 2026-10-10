---
title: Usage guide
layout: default
parent: Operate
nav_order: 1
description: >-
  When to use ACM public vs Private CA, when split-horizon DNS fits, best
  practices, and what to avoid.
---

# Usage guide
{: .no_toc }

<span class="svc-pair">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="AWS Certificate Manager" width="48" height="48" loading="lazy">
  <img class="svc-icon" src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Private-Certificate-Authority_64.svg" alt="AWS Private Certificate Authority" width="48" height="48" loading="lazy">
</span>

Complementary, not rivals. Pick by **who must trust the issuer.**
{: .fs-5 .fw-300 }

## Pick a path

<div class="path-grid">
  <div class="path-card">
    <span class="path-card__label">Public</span>
    <span class="path-card__icons">
      <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="" width="40" height="40" loading="lazy">
      <img src="https://aws-icons.johna.kiwi/icons/resource/networking/Res_Elastic-Load-Balancing_Application-Load-Balancer_48.svg" alt="" width="40" height="40" loading="lazy">
    </span>
    <strong>ACM public</strong>
    <p>Internet endpoint. <a href="https://docs.aws.amazon.com/acm/latest/userguide/certificate-types.html">Trusted by browsers and OSes</a> with zero client setup. Attach to ALB, CloudFront, or API Gateway.</p>
    <span class="path-card__meta">no CA install</span>
  </div>
  <div class="path-card">
    <span class="path-card__label">Private</span>
    <span class="path-card__icons">
      <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Private-Certificate-Authority_64.svg" alt="" width="40" height="40" loading="lazy">
      <img src="https://aws-icons.johna.kiwi/icons/resource/management/Res_AWS-Systems-Manager_State-Manager_48.svg" alt="" width="40" height="40" loading="lazy">
    </span>
    <strong>Private CA</strong>
    <p>Internal name, your PKI. Only clients you install the CA on will trust it. Certs can live on nginx/EC2.</p>
    <span class="path-card__meta">you operate trust</span>
  </div>
  <div class="path-card">
    <span class="path-card__label path-card__label--warn">Hybrid</span>
    <span class="path-card__icons">
      <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="" width="40" height="40" loading="lazy">
      <img src="https://aws-icons.johna.kiwi/icons/service/networking/Arch_Amazon-Route-53_64.svg" alt="" width="40" height="40" loading="lazy">
    </span>
    <strong>Split-horizon</strong>
    <p>Public ACM on a name that resolves only inside the VPC. Amazon trust, no fleet CA. Documented, not in the lab.</p>
    <span class="path-card__meta">optional</span>
  </div>
</div>

## Decision table

| Situation | Reach for |
| --- | --- |
| Public website or API; no client setup | **ACM public** on ALB / CloudFront / API Gateway |
| Internal name; only managed clients trust | **Private CA** + CA distribution |
| Internal name on an ALB (ACM-integrated) | **Private CA** → ACM private cert (`alb_acm`) |
| Internal name, but clients trust Amazon's CA | **Public ACM** + [split-horizon]({{ site.baseurl }}/architecture/#split-horizon-dns-public-acm-on-an-internal-name) |
| Cert on nginx / EC2 / appliance | **Private CA** export / `IssueCertificate` (`nginx_export`) |
| You bought a cert elsewhere | **Import into ACM** for ALB / CloudFront |
| Unmanaged BYOD on the internet | **ACM public** |
| mTLS between internal services | **Private CA** |

## Do and don't

<div class="path-grid">
  <div class="path-card">
    <span class="path-card__label">Do</span>
    <strong>Separate the two trust paths</strong>
    <p>DNS-validate ACM public and keep it in use so <a href="https://docs.aws.amazon.com/acm/latest/userguide/managed-renewal.html">managed renewal</a> runs. Validation CNAMEs in the <strong>public</strong> zone only. Cert in the ALB's Region. Treat CA install as fleet config (SSM), not a one-off. Keep leaf keys in Secrets Manager. Rotate CAs with an overlap window; rotate leaves on their own schedule.</p>
  </div>
  <div class="path-card">
    <span class="path-card__label path-card__label--warn">Don't</span>
    <strong>Mix or hand-wire trust</strong>
    <p>No Private CA for a public site — Chrome won't trust it. No classic ACM public key on EC2. No hand-installing the CA host by host. Don't call private TLS "working" off <code>curl --cacert</code>. Don't leave a Private CA <code>ACTIVE</code> after a demo. Never ship a CA or leaf private key to clients.</p>
  </div>
</div>

{: .avoid }
> The fastest way to a bad day: Private CA on a public marketing site, a CA
> private key shipped to clients, or ACM validation CNAMEs hidden in a
> private-only zone.

## Split-horizon DNS (optional)

Public ACM on a name that **resolves only inside** the VPC/VPN, with clients
trusting TLS **without** your CA.

| Public zone | Private zone |
| --- | --- |
| ACM DNS validation CNAMEs | Alias → internal ALB / service |

Standard Route 53 [split-view](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-considerations.html).
Prefer **Private CA** when you own the issuer and only managed clients should
trust. Not applied here — diagram:
[Architecture — split-horizon]({{ site.baseurl }}/architecture/#split-horizon-dns-public-acm-on-an-internal-name).

## Related pages

- [Introduction]({{ site.baseurl }}/introduction/)
- [Architecture — split-horizon]({{ site.baseurl }}/architecture/#split-horizon-dns-public-acm-on-an-internal-name)
- [Trust distribution]({{ site.baseurl }}/trust-distribution/)
- [Cost]({{ site.baseurl }}/cost/)
- [Troubleshooting]({{ site.baseurl }}/troubleshooting/)
