---
id: vendored-copy-must-be-adapted-not-branded
agent: [platform-engineer]
trigger: [vendoring a functional equivalent script, adapting sdlc scripts for gtm, session-key sentinel naming]
rule: '"Vendored functional equivalent" means a genuinely adapted copy, not a literal branded copy.'
evidence: [NA-3]
uses: 0
status: active
---

## Why

The sdlc scripts (`session-key.sh`/`tmp-dir.sh`/`cleanup-tmp.sh`/`session-complete.sh`) referenced
`SDLC_SESSION_KEY` and sdlc-specific commands (`/auto`, `/impl`, `refs/triage.md`) in comments —
left as-is these would be misleading/wrong inside a standalone gtm package. Renamed the env var to
`GTM_SESSION_KEY`, the sentinel to `GTM_SESSION_COMPLETE`, and rewrote sdlc-specific prose to
reference gtm commands. A generic, source-agnostic piece (e.g. a `CLAUDE_CODE_SESSION_ID` fallback)
needs no change.
