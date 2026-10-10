---
title: Overview
layout: default
nav_order: 1
description: >-
  Complementary public and private TLS on AWS — ACM for internet trust,
  Private CA for intranet PKI, with Linux CA trust distribution.
---

<div class="conduit-hero">
  <p class="conduit-kicker">johna.kiwi · acm-public-vs-private-ca-walkthrough</p>
  <h1>ACM and Private CA</h1>
  <p class="conduit-lede">
    Public TLS and private TLS are different jobs. This lab runs both in one VPC:
    <strong>ACM</strong> on an ALB for internet trust, <strong>AWS Private CA</strong>
    via ACM on an internal ALB for intranet PKI (optional nginx export), and
    <strong>S3 + SSM</strong> so a Linux fleet learns your CA without hand-copying PEMs.
  </p>
  <div class="conduit-actions">
    <a class="conduit-btn conduit-btn--primary" href="{{ site.baseurl }}/walkthrough/">Deploy the lab</a>
    <a class="conduit-btn conduit-btn--ghost" href="{{ site.baseurl }}/architecture/">See architecture</a>
    <a class="conduit-btn conduit-btn--ghost" href="{{ site.baseurl }}/concepts/">Trust models</a>
  </div>
</div>

## Two paths, one trust story

<div class="path-grid">
  <a class="path-card" href="{{ site.baseurl }}/architecture/">
    <span class="path-card__label">Public</span>
    <span class="path-card__icons">
      <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="AWS Certificate Manager" width="40" height="40" loading="lazy">
      <img src="https://aws-icons.johna.kiwi/icons/resource/networking/Res_Elastic-Load-Balancing_Application-Load-Balancer_48.svg" alt="Application Load Balancer" width="40" height="40" loading="lazy">
    </span>
    <strong>ACM on the ALB</strong>
    <p>Browsers already trust Amazon’s public CA. Terminate HTTPS on the load balancer; the backend stays HTTP.</p>
    <span class="path-card__meta">demo.johna.kiwi</span>
  </a>
  <a class="path-card" href="{{ site.baseurl }}/architecture/">
    <span class="path-card__label">Private</span>
    <span class="path-card__icons">
      <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Private-Certificate-Authority_64.svg" alt="AWS Private Certificate Authority" width="40" height="40" loading="lazy">
      <img src="https://aws-icons.johna.kiwi/icons/service/security/Arch_AWS-Certificate-Manager_64.svg" alt="AWS Certificate Manager" width="40" height="40" loading="lazy">
    </span>
    <strong>Private CA + ACM on internal ALB</strong>
    <p>Same ALB pattern as public. Clients trust it only after the CA PEM is in the system store.</p>
    <span class="path-card__meta">app.internal.johna.kiwi</span>
  </a>
  <a class="path-card" href="{{ site.baseurl }}/trust-distribution/">
    <span class="path-card__label path-card__label--warn">Trust</span>
    <span class="path-card__icons">
      <img src="https://aws-icons.johna.kiwi/icons/resource/storage/Res_Amazon-Simple-Storage-Service_Bucket_48.svg" alt="Amazon S3 bucket" width="40" height="40" loading="lazy">
      <img src="https://aws-icons.johna.kiwi/icons/resource/management/Res_AWS-Systems-Manager_State-Manager_48.svg" alt="AWS Systems Manager State Manager" width="40" height="40" loading="lazy">
    </span>
    <strong>S3 + SSM install</strong>
    <p>Publish the CA PEM once. State Manager installs it on tagged hosts; unmanaged clients fail on purpose.</p>
    <span class="path-card__meta">TrustCA=intranet</span>
  </a>
</div>

{% include diagrams/landing-flow.html %}

## What this covers

**Complementary, not rivals.** Use ACM public for anything the internet must trust.
Use Private CA when names and hosts stay inside your estate and you control the trust anchor.

**What the lab proves.** Public URL works in a default browser. Managed Linux client
opens the private URL without `--cacert`. Unmanaged client gets an untrusted-issuer failure.

**What you still own in production.** CA lifecycle, renewal automation for private leaves,
and a fleet trust channel that matches how you already configure hosts.

{: .tip }
> Start with [Concepts]({{ site.baseurl }}/concepts/) if you want the trust-model split
> first, or jump to [Walkthrough]({{ site.baseurl }}/walkthrough/) if you already know
> ACM vs Private CA and want to apply the stack.

## Read in this order

**[Learn]({{ site.baseurl }}/learn/)** — the trust model before you build.

<div class="nav-grid">
  <a class="nav-card" href="{{ site.baseurl }}/introduction/">
    <strong>Introduction</strong>
    <span>What ACM and Private CA do at a high level</span>
  </a>
  <a class="nav-card" href="{{ site.baseurl }}/concepts/">
    <strong>Concepts</strong>
    <span>Trust models, export, cost shape</span>
  </a>
</div>

**[Deploy]({{ site.baseurl }}/deploy/)** — stand up the lab and prove both paths.

<div class="nav-grid">
  <a class="nav-card" href="{{ site.baseurl }}/architecture/">
    <strong>Architecture</strong>
    <span>ALB public + internal private paths, hosts</span>
  </a>
  <a class="nav-card" href="{{ site.baseurl }}/trust-distribution/">
    <strong>Trust distribution</strong>
    <span>Linux CA install via S3 and SSM</span>
  </a>
  <a class="nav-card nav-card--primary" href="{{ site.baseurl }}/walkthrough/">
    <strong>Walkthrough →</strong>
    <span>Apply, prove, tear down — the main runbook</span>
  </a>
</div>

**[Operate]({{ site.baseurl }}/operate/)** — run it well, then decide when to use which.

<div class="nav-grid">
  <a class="nav-card" href="{{ site.baseurl }}/usage-guide/">
    <strong>Usage guide</strong>
    <span>When to use which, what to avoid</span>
  </a>
  <a class="nav-card" href="{{ site.baseurl }}/cost/">
    <strong>Cost</strong>
    <span>Wildcards, renewal, Private CA monthly</span>
  </a>
  <a class="nav-card" href="{{ site.baseurl }}/troubleshooting/">
    <strong>Troubleshooting</strong>
    <span>Failure signatures and fixes</span>
  </a>
  <a class="nav-card" href="{{ site.baseurl }}/reference/">
    <strong>Reference</strong>
    <span>Repo map, Terraform outputs, prove commands</span>
  </a>
</div>

{: .cost }
> **Private CA bills monthly** while the CA exists — [charged from creation until deletion](https://docs.aws.amazon.com/privateca/latest/userguide/PcaWelcome.html), so destroy when finished.
> Public ACM certificates [add no charge beyond the AWS resources that use them](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html); ALB and EC2 still cost while running.
> Detail: [Cost]({{ site.baseurl }}/cost/).

## Prerequisites in brief

- Terraform >= 1.5, AWS CLI v2, Session Manager plugin
- Route 53 hosted zone for `johna.kiwi` (or override hostnames in `terraform.tfvars`)
- Region default `ap-southeast-2`
- Four Terraform stages under `terraform/01-network` … `04-trust` (not one monolith apply)

Full steps: [Walkthrough]({{ site.baseurl }}/walkthrough/).
