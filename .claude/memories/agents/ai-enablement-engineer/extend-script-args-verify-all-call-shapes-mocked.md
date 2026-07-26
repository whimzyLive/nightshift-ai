---
id: extend-script-args-verify-all-call-shapes-mocked
agent: [ai-enablement-engineer]
trigger: [extending a script's positional args with optional trailing args, must stay backward-compatible]
rule: When extending a script's positional-arg contract with new OPTIONAL trailing args while the original call shape must stay byte-for-byte behaviorally identical, verify with an actual mocked end-t.
evidence: [NA-47]
uses: 0
status: active
---

## Why

Built minimal `gh`/`acli` mocks in the scratchpad (env-var-switched mode) and ran the script under a
`PATH` override for all four shapes — confirmed the 1-arg path prints identical output to before,
and the 3-arg paths hit no-op/success/warning-then-still-succeeds correctly. This catches
`set -euo pipefail` interaction bugs (e.g. an unguarded call inside a best-effort block that would
abort the whole script) a static read alone would not surface.
