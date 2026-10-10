---
inclusion: always
---

# Structure

## Terraform

Four staged roots under `terraform/` (local `terraform_remote_state` between them):

| Stage | Path |
| --- | --- |
| Network | `terraform/01-network` |
| Public ACM | `terraform/02-public` |
| Private CA | `terraform/03-private` |
| Trust | `terraform/04-trust` |

- One shared `terraform/terraform.tfvars` (pass `-var-file=../terraform.tfvars`).
- Outputs per stage; prove scripts read the stage that owns the resource.
- Destroy reverse order — Private CA is in stage 03.

## Docs (just-the-docs)

Nav groups:

| Section | Pages |
| --- | --- |
| Overview | `docs/index.md` |
| Learn | introduction, concepts |
| Deploy | architecture, trust-distribution, walkthrough |
| Operate | usage-guide, cost, troubleshooting, reference |

- Walkthrough = staged apply + verify (not one monolith apply).
- Diagrams are HTML/CSS includes under `docs/_includes/diagrams/` (AWS icons).
- Keep content width stable: `scrollbar-gutter: stable` + `overflow-y: scroll` on `html`.

## Scripts

- `prove-public.sh` — after stage 02
- `prove-private-tls.sh` — after stage 03 (TLS up, trust not yet)
- `prove-private-untrusted.sh` / `prove-private-managed.sh` — after stage 04
- `install-ca-trust.sh` — what SSM runs on managed clients
- No agent-runnable apply wrappers

## CI

- `markdown-lint.yml` + `commitmsg-conform.yml` only for hygiene
- Deploy docs via existing Pages/Jekyll workflow if present
- Never run live `terraform apply` in CI
