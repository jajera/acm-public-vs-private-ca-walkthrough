---
title: Deploy
layout: default
nav_order: 3
has_children: true
description: >-
  Stand up the lab in four Terraform stages and prove both trust paths.
---

# Deploy

Stand up the lab and prove both trust paths. The [Walkthrough]({{ site.baseurl }}/walkthrough/)
is the main runbook — four staged applies, verify after each, then tear down.

- [Architecture]({{ site.baseurl }}/architecture/) — public/private subnets, ALB paths, optional nginx export, hosts.
- [Trust distribution]({{ site.baseurl }}/trust-distribution/) — Linux CA install via S3 and SSM.
- [Walkthrough]({{ site.baseurl }}/walkthrough/) — staged Terraform, prove scripts, destroy.

{: .cost }
> **Private CA bills monthly** while the CA exists — [charged from creation until deletion](https://docs.aws.amazon.com/privateca/latest/userguide/PcaWelcome.html).
> Billing starts at stage 3. Tear down in the same session. Detail: [Cost]({{ site.baseurl }}/cost/).
