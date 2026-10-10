---
inclusion: always
---

# Lab safety

## Mutation guard

Do **not** run mutating AWS or Terraform commands unless:

```bash
export ACM_LAB_ALLOW_AWS=1
```

Blocked without the flag (non-exhaustive): `terraform apply`, `terraform destroy`,
`aws acm*`, `aws acm-pca`, `aws elbv2`, `aws ec2 run-instances`, `aws s3 rm`,
`aws ssm send-command`, `aws secretsmanager`, Route 53 change-resource-record-sets
that create/delete lab records.

Allowed without the flag: `terraform fmt` / `validate` / `plan` (plan is OK if
it does not require writing state to a remote that mutates; prefer local plan),
read-only `aws` describe/list/get, docs build, markdown lint.

## Cost awareness

- Private CA (~$400/month short-lived CA class or per pricing page) accrues while
  the CA exists — destroy promptly after demos.
- Public ACM certs on ALB are $0 for the certificate itself when used with
  integrated services; data transfer / ALB hours still apply.
- Keep lab lifetime short; document teardown in `docs/teardown.md`.

## Secrets

- Never commit private keys, CA PEMs used as production roots, or `.tfstate`.
- Lab leaf keys may live in Secrets Manager only; do not echo them into docs.

## Domain

- Lab hostnames under `johna.kiwi` (e.g. `demo.johna.kiwi`,
  `app.internal.johna.kiwi`). Do not invent other public domains without asking.
