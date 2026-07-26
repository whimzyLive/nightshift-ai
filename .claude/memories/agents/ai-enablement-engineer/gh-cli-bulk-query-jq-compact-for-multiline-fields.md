---
id: gh-cli-bulk-query-jq-compact-for-multiline-fields
agent: [ai-enablement-engineer]
trigger: [gh pr list --json body, N+1 gh calls, multiline field breaks TSV per-line loop]
rule: "Replace an N+1 `gh` calls pattern with a single `gh pr list --json <fields>`; when a field is multi-line text, pipe through `jq -c '.[]'` (local, compact mode) so each record stays one physical line."
evidence: [NA-7]
uses: 0
status: active
---

## Why

A naive `--jq '.[] | "\(.headRefName)\t...\(.body)"'` TSV-per-line approach breaks immediately since
embedded body newlines split what should be one logical row across several physical lines;
`jq -c` escapes embedded newlines as `\n` inside the JSON string, sidestepping the issue.
