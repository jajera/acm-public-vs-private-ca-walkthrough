---
title: Troubleshooting
layout: default
parent: Operate
nav_order: 3
description: >-
  Failure signatures for ACM validation, Private CA trust, SSM install, and
  staged Terraform destroy.
---

# Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Public cert stuck `PENDING_VALIDATION` | DNS validation CNAMEs missing or wrong zone | Confirm `route53_zone_id` is a **public** zone in the **lab account**; wait for propagation |
| Stage 02 fails creating Route 53 records | Zone in another account / wrong ID | Use a same-account public zone (or delegated subzone); do not point at a management-account zone |
| Public ACM pending; dual public/private zones | Validation CNAME only in the **private** zone | Create the ACM CNAME in the **public** hosted zone ([split-horizon]({{ site.baseurl }}/architecture/#split-horizon-dns-public-acm-on-an-internal-name)) |
| `demo.johna.kiwi` certificate name mismatch | Cert requested for different FQDN | Align `public_hostname` and Route 53 record |
| ALB HTTPS works but shows wrong cert | Listener not using the ACM ARN | Check `aws_lb_listener` certificate_arn |
| Private URL fails on managed client | SSM association not finished or tag missing | Check association status; confirm `TrustCA=intranet` |
| Managed client still fails after association | CA not in system store | Re-run association; inspect `/etc/pki/ca-trust/source/anchors/` |
| Unmanaged client unexpectedly succeeds | System already trusts a similar CA | Use a fresh instance; do not install CA there |
| `curl --cacert` works, system curl fails | Trust install skipped; you bypassed the store | Fix SSM install; do not treat `--cacert` as pass |
| Internal ALB private HTTPS unhealthy / no leaf | ACM private cert or target health | Confirm `private_tls_mode=alb_acm`, ACM cert `ISSUED`, target on `:80`, private DNS alias to ALB |
| nginx on private host not serving TLS (`nginx_export`) | State Manager leaf install failed | Check association for `LabRole=private-web`; instance role `secretsmanager:GetSecretValue`; SSM agent online |
| `terraform destroy` blocked on Private CA | Wrong destroy order or leftover deps | Destroy `04-trust` then `03-private`; retry |
| Stage 4 apply cannot read remote state | Stage 1 or 3 never applied / state moved | Re-apply earlier stages on the same machine |
| Surprise bill after demo | Private CA left `ACTIVE` | Delete CA in console/CLI; verify billing |

More context: [Trust distribution]({{ site.baseurl }}/trust-distribution/),
[Walkthrough]({{ site.baseurl }}/walkthrough/).
