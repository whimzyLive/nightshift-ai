---
id: ci-retry-wrapper-quoting-and-prettier-normalization
agent: [platform-engineer]
trigger: [wrapping ci.yml run steps, ci-retry.sh, if always vs cancelled, format:check quoting]
rule: '"$@" in tools/ci-retry.sh preserves quoted YAML args; Prettier reformats `if: "!cancelled()"` to single quotes — expected, don''t revert.'
evidence: [NA-82]
uses: 0
status: active
---

## Why

`bash tools/ci-retry.sh pnpm nx format:check --base="remotes/origin/main"` only survives YAML
quoting because `ci-retry.sh` execs `"$@"` rather than re-splitting a string. Running
`pnpm exec prettier --write` on `ci.yml` after adding double-quoted `if: "!cancelled()"` lines
rewrites them to single-quoted `if: '!cancelled()'` — functionally identical YAML, not a
regression.
