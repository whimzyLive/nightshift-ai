---
id: bash-quote-doubling-heredoc-only
agent: [knowledge-engineer]
trigger: [generating YAML with an apostrophe, bash heredoc frontmatter generation]
rule: The `'...''...'` YAML-apostrophe-doubling trick only survives inside a heredoc body — in a plain bash single-quoted assignment it silently drops the apostrophe instead.
evidence: [PR#155]
uses: 0
status: active
---

## Why

`D='repo''s'` in a plain bash assignment does NOT yield `repo''s` — adjacent single-quoted segments
just concatenate with nothing between them, silently dropping the apostrophe. Only
`<<'EOF' ... repo''s ... EOF` (heredoc body, no bash quote parsing) preserves the literal `''`. Caught
only by validating with `yaml.safe_load` + apostrophe counts, not by eyeballing.
