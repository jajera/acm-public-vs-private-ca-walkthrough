---
inclusion: always
---

# Docs style

## Voice

- Direct, factual, operator-facing. No defensive hedging (“this is only a demo…”
  repeated). State what the lab proves and what production still needs.
- Prefer “do X” over “you might want to consider X.”

## README vs walkthrough

- **README.md** — how to run: prerequisites, tfvars, apply, prove scripts,
  teardown pointer. Keep short.
- **docs/walkthrough.md** — Terraform/CLI detail, resource rationale.
- **docs/concepts.md** — trust model (public vs private), not a second runbook.

## Cost page

- Wildcard vs FQDN tradeoffs with concrete reasons.
- ACM public renewal conditions (in use + validation records).
- Private CA monthly + issuance + trial notes with AWS pricing as source.
- Tables preferred over long prose.

## just-the-docs

- Use `title`, `nav_order`, `parent` / `has_children` as needed.
- Mermaid OK in architecture.
- Link relative paths under `docs/`.

## Code citation in chat

When pointing at repo files, use Cursor code-reference format for existing code.
For new snippets in docs, fenced blocks with language tags.
