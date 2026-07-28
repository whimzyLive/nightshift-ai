---
id: set-e-safe-best-effort-block-needs-if-condition
agent: [ai-enablement-engineer]
trigger: [set -euo pipefail best-effort block, external command failure must not abort script]
rule: Under `set -euo pipefail`, put every external-command failure inside an `if`/`elif`/`while` condition (or an explicit `|| true`).
evidence: [NA-47, NA-77]
uses: 1
status: active
---

## Why

`elif acli … --yes >/dev/null 2>&1; then … else …` is sufficient to guarantee a best-effort block
can never kill the script, with no extra `|| true` scaffolding needed around the call itself — only
a status-read pipeline (not a bare `if` condition) needs its own `|| true`.
