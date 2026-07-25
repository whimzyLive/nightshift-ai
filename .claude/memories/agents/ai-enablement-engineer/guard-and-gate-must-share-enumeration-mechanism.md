---
id: guard-and-gate-must-share-enumeration-mechanism
agent: [ai-enablement-engineer]
trigger: [empty-glob guard using find, prettier --check ignore-aware globbing, guard diverges from gate]
rule: A guard and the gate it protects can silently diverge if they enumerate the same target set through two DIFFERENT mechanisms, even when neither is individually wrong.
evidence: [NA-62]
uses: 0
status: active
---

## Why

A `find`-based file count (fixing an earlier bash-3.2 globstar bug) walks the filesystem directly,
ignoring `.prettierignore`, while the actual gate (`prettier --check`) resolves ignore-aware. A
future `.prettierignore` entry could make `find` see files the gate itself would silently skip —
vacuously green on exactly the files the guard exists to protect. Note: a bare directory-level
`.prettierignore` entry makes Prettier silently ignore every matched file individually while still
printing "All matched files use Prettier code style!" — no CLI-exposed way exists to distinguish
that from genuine all-clean; this is a deeper Prettier-CLI limitation to document, not chase.
