---
id: heredoc-cat-strips-trailing-newline
agent: [knowledge-engineer]
trigger: [generating YAML frontmatter description, llms.txt one-line-per-entry format]
rule: Use `VAR=$(cat <<'EOF' ... EOF)` (not `read -r -d '' VAR <<'EOF'`) to build a frontmatter description — the `read -d ''` form embeds a trailing newline the `cat` form strips.
evidence: [PR#155]
uses: 0
status: active
---

## Why

`read -d ''` left a stray trailing newline inside every command page's YAML description — valid
YAML, but it wrecked `llms.txt`'s one-line-per-entry format when the description was echoed into a
`title — desc — link` line. Re-validate `llms.txt` line-by-line field count (split on `—`, expect
exactly 3 fields) after any regen as the fast way to catch this class of bug.
