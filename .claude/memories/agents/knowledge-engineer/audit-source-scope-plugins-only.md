---
id: audit-source-scope-plugins-only
agent: [knowledge-engineer]
trigger: [doc generation source-of-truth, skill-reference dedup, resolving auto row inputs]
rule: When resolving any `auto` doc-generation row's source-of-truth, scope strictly to `plugins/{sdlc,gtm}/**` — never repo-root mirrors, consumer-repo files, or this repo's own filled-in config.
evidence: [PR#155]
uses: 0
status: active
---

## Why

An early approach deduped repo-root `skills/` mirrors against their `.github/`/`.opencode/` copies to
pick one canonical page per skill. A later scope-rule change invalidated that entirely: source of
truth is `plugins/{sdlc,gtm}/**` only, full stop — repo-root `skills/` is out of scope regardless of
dedup. A scope-rule change like this needs a full re-partition of the source set, not an incremental
fix layered on the old dedup logic.
