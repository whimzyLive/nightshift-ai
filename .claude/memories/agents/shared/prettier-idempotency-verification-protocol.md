---
id: prettier-idempotency-verification-protocol
agent: [ai-enablement-engineer, knowledge-engineer]
trigger: [verifying markdown stability, scratch-copy idempotency check, prettier --write twice, hand-typed table padding]
rule: 'Verify a markdown edit is Prettier-stable via an in-tree scratch copy: confirm `prettier --file-info` reports `ignored: false` + a parser, then require a second `--write` to be a no-op.'
evidence: [NA-25, NA-27, NA-43, NA-44, NA-51, NA-52, NA-56, NA-57, NA-60, NA-61, NA-62, NA-65]
uses: 0
status: active
---

## Why

Several independent false-negative traps recur: a scratch copy outside the repo tree or under a
`.gitignore`d dir (or with a non-`.md` suffix) is silently `ignored`/has `inferredParser: null`, so
`--write` no-ops and any "STABLE" result is meaningless. A hand-typed markdown table (even one
copied verbatim from a plan) is almost never Prettier-idempotent on the first `--write` — never
hand-match Prettier's column padding, run `--write` and trust its output as authoritative, then
re-verify idempotency from that written state. This repo's real pre-commit hook (`lint-staged` /
`prettier --write --ignore-unknown`) is the actual gate — a pre-commit `--check`/`--write` dry run
never proves what actually lands; only `git show <sha> -- <file>` after the commit does.
