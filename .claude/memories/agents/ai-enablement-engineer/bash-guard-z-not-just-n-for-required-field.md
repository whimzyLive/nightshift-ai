---
id: bash-guard-z-not-just-n-for-required-field
agent: [ai-enablement-engineer]
trigger: [bash validator required field, check-frontmatter.sh, -n guarded format check]
rule: A bash guard shaped `[ -n "$val" ] && <format-check>` only checks "if present, is it well-formed".
evidence: [NA-73]
uses: 0
status: active
---

## Why

`check-frontmatter.sh`'s `id` and `rule` field checks had this shape, so `id:` or `rule:` with
nothing after the colon produced zero lint issues. Fixed by inverting to
`if [ -z "$val" ]; then <fail>; else <format checks>; fi` for every required-non-empty field.
