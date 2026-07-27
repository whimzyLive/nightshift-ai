---
id: grep-guard-must-cover-flag-form-variants
agent: [ai-enablement-engineer]
trigger: [grep-based CI guard for a specific CLI flag misuse, short flag alias, --flag=value form, single-quoted value]
rule: A grep guard against a hardcoded CLI flag must match its short-flag alias, `=value` form, and single-quoted values too, not just long-flag-space-value — else the defect can reappear.
evidence: [NA-78]
uses: 0
status: active
---

## Why

`--project[[:space:]]+"?[A-Z]{2,10}"?` caught `--project ET`/`--project "CER"` but missed
`--project 'ABC'` (single quotes), `--project=XYZ` (`=` form), and `-p ET` (the documented short
flag, `skills/acli/SKILL.md:76`) — all real syntaxes the same CLI accepts, verified by QA
mutation-testing. A guard that only covers the one syntax it happened to see in the original bug
report gives a false sense of coverage.
