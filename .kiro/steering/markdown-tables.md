---
inclusion: always
---

# Markdown tables

GFM tables need a header row, a separator row (`| --- | --- |`), and consistent
column counts. Do not put unescaped `|` inside cells.

After editing Markdown, rely on `.kiro/hooks/format-md-tables.py` (wired via
`format-markdown-tables.json`) rather than hand-fixing separator rows in a rush.

Prefer simple two- or three-column tables for cost, host roles, and CLI summaries.

This site is **Jekyll + just-the-docs** (plain `.md`), not Starlight MDX — pipe
tables are the default. Do not introduce HTML `<table>` or Astro `Tooltip`
patterns from other walkthroughs.
