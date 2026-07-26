---
id: version-write-must-fail-loud-not-silently-skip
agent: [platform-engineer]
trigger: [updateProjectVersion, manifest write guard, nx release tag vs manifest drift]
rule: A version-manifest write step must throw on every failure path (unreadable manifest, zero matches, ambiguous multiple matches) instead of `continue`-ing past it.
evidence: [NA-63]
uses: 0
status: active
---

## Why

The original code's `if (!contents || !VERSION_FIELD_PATTERN.test(contents)) continue;` let
`nx release` still tag + write CHANGELOG.md even when the `plugin.json` write was silently skipped,
producing permanent, undetected tag↔manifest drift. Fixed by throwing on every failure path, and by
switching from `.test()` (proves ≥1 match exists) to a global match-count check (exactly 1 required;
0 or >1 both throw, naming the manifest path). After the fix, re-run
`./node_modules/.bin/nx release --dry-run --first-release` to prove the happy path is unaffected —
`git status --porcelain` should show zero mutation.
