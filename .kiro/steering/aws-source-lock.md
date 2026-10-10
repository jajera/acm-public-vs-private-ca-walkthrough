---
inclusion: always
---

# AWS source lock

Behavioural claims about ACM, AWS Private CA, renewal, and pricing must be grounded.

## Prefer

1. Links to current AWS documentation or pricing (use aws-docs MCP: search → read).
2. Facts verified in this account and listed below (when an evidence pass exists).
3. Explicit **unverified** markers for steps not yet run.

## Do not

- Invent renewal conditions, Private CA monthly amounts, or CLI flags from memory.
- Cite blog posts as authoritative over AWS docs for API or billing behaviour.
- Claim ACM public renews orphan unused certificates; managed renewal requires the
  cert to be **in use** with an integrated service (and valid DNS CNAMEs as documented).

## Primary sources

| Topic | Prefer |
| --- | --- |
| ACM public pricing / $0 with integrated services | AWS Certificate Manager pricing |
| Private CA monthly, issuance fees, trial | AWS Private CA pricing |
| Managed renewal for ACM public | ACM User Guide — managed renewal |
| DNS validation / CNAME records | ACM User Guide — DNS validation |
| ALB HTTPS listener + ACM | ELB User Guide |
| Private CA issue / export | AWS Private CA User Guide |
| SSM State Manager / Run Command | Systems Manager User Guide |
| Secrets Manager for private key material | Secrets Manager User Guide |

## Cost / renewal edits

When editing `docs/cost.md` or renewal claims:

1. Check current AWS pricing pages (USD list; note Region narrative).
2. State assumptions (short-lived lab, CA mode, issuance count).
3. Note Private CA monthly is **pro-rated** and billable while the CA exists.
4. If AWS docs and this repo disagree, fix the repo and cite the AWS page in the PR body.

## Verified facts

Lab stages 01–04 were applied and proved in `ap-southeast-2` (default
`alb_acm`), then destroyed. Walkthrough “Verified results” blocks are historical
examples (IDs change each apply). Append dated pricing/API facts here only after
an intentional evidence pass — never real account IDs or private keys in
`docs/**`.
