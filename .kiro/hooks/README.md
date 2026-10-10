# Hooks

Kiro v1 hooks ([reference](https://kiro.dev/docs/hooks/)).

| File | Trigger | Blocks | Purpose |
| --- | --- | --- | --- |
| `guard-aws-mutations.json` | `PreToolUse` | yes \| Refuses mutating AWS CLI / `terraform apply | destroy` unless `ACM_LAB_ALLOW_AWS=1` |
| `cite-aws-claims.json` | `PostFileSave` | no | Ground ACM/Private CA claims after editing `docs/**/*.md` |
| `format-markdown-tables.json` | `PostFileSave` | no | Repairs broken GFM tables in dirty Markdown |

```bash
export ACM_LAB_ALLOW_AWS=1
```

Test the guard without Kiro:

```bash
echo '{"command":"terraform apply"}' | python3 .kiro/hooks/guard-aws-mutations.py; echo "exit=$?"
echo '{"command":"aws sts get-caller-identity"}' | python3 .kiro/hooks/guard-aws-mutations.py; echo "exit=$?"
```
