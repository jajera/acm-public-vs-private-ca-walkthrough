---
inclusion: always
---

# Product

All-in-one **ACM public + AWS Private CA** walkthrough: public TLS on an
internet-facing ALB and private TLS on an **internal ALB** (ACM private cert from
Private CA by default), with Linux CA trust distribution (S3 + SSM State Manager).
Optional `nginx_export` mode keeps the Secrets Manager → nginx leaf path.

They are complementary — not competitors. Docs: just-the-docs under `docs/`.
Lab: Terraform under `terraform/`. Prove scripts under `scripts/`.

## Audience

Engineers who know TLS basics and need a clear split: when ACM public is enough,
when Private CA is required, and how to install a CA on a Linux fleet without
hand-copying PEMs.

## Outcomes

1. ACM public cert on ALB for `demo.johna.kiwi` (DNS validation, default browser trust).
2. Default private path: ACM private cert from Private CA on an internal ALB for
   `app.internal.johna.kiwi` (HTTP backend). Optional `nginx_export` mode: PCA
   leaf in Secrets Manager + State Manager on nginx.
3. CA PEM published to hardened S3; SSM State Manager installs trust on tagged clients.
4. Unmanaged client fails TLS; managed client succeeds without `--cacert`.
5. Cost, wildcards, and renewal facts grounded in AWS pricing/docs.
6. Usage guide after teardown: when to use which, what to avoid.

## Non-goals (v1)

- Windows / AD / GPO / Intune / Private CA Connector for AD
- CloudFront as the primary public path (footnote only: `us-east-1`)
- Framing ACM vs Private CA as mutually exclusive
- CI that runs `terraform apply` against a live account
- Astro/Starlight (this site is Jekyll just-the-docs)
