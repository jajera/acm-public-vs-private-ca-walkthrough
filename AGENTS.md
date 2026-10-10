# Agent guide — acm-public-vs-private-ca-walkthrough

Read this and `.kiro/steering/` before changing docs or Terraform.
Cursor rules under `.cursor/rules/` mirror the same constraints.

## What this repo is

An **all-in-one** Jekyll (just-the-docs) walkthrough + Terraform lab: **ACM public**
TLS on an ALB (`demo.johna.kiwi`) alongside **AWS Private CA** on an internal ALB
with an ACM private cert (`app.internal.johna.kiwi`; optional `nginx_export`
mode), with Linux CA trust via S3 + SSM State Manager.

Terraform is **four staged roots** (`01-network` … `04-trust`) with verify after
each apply — not one monolith. Public and private paths are complementary.
No Astro/Starlight. CI does not run `terraform apply`.

## Before you edit

| Topic | File |
| --- | --- |
| Product / non-goals | `.kiro/steering/product.md` |
| Stack and layout | `.kiro/steering/tech.md` |
| Authoring layout | `.kiro/steering/structure.md` |
| Mutation guard | `.kiro/steering/lab-safety.md` |
| AWS claims | `.kiro/steering/aws-source-lock.md` |
| Docs voice | `.kiro/steering/docs-style.md` |
| Terraform conventions | `.kiro/steering/terraform-stack.md` |
| GFM tables | `.kiro/steering/markdown-tables.md` |

## Mutation guard

```bash
export ACM_LAB_ALLOW_AWS=1   # operator only, deliberate lab
```

Agents author apply/destroy/prove commands; the human runs them.

## Docs site

```bash
./scripts/docs-serve.sh
```

Live: `https://acm-public-vs-private-ca-walkthrough.johna.kiwi/`

README = how to run. `docs/walkthrough.md` = Terraform/CLI depth.
`docs/cost.md` = pricing, wildcards, renewal (AWS sources only).

## Hygiene

- Keep markdown-lint + commitmsg-conform workflows.
- Commit subjects: conform types, US spelling, body required.
- Never commit private keys, CA PEMs meant for production, or `.tfstate`.
