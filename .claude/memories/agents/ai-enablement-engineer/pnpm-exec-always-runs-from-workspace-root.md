---
id: pnpm-exec-always-runs-from-workspace-root
agent: [ai-enablement-engineer]
trigger: [testing an empty-glob scenario, pnpm exec from a nested scratch directory]
rule: "`pnpm exec <cmd>` always executes from the pnpm workspace root, regardless of the invoking shell's cwd."
evidence: [NA-62]
uses: 0
status: active
---

## Why

A "fake empty plugins/ dir nested under `.tmp/`" test produced a false "all clean" result unrelated
to the guard logic under test. The valid way to test an empty-match scenario for a `pnpm exec`-based
script: point the glob at a guaranteed-nonexistent subpath while still invoking from the real repo
root, or temporarily edit `.prettierignore` and revert with `git checkout --` immediately after —
never relocate the script to fake a different cwd for a `pnpm exec` call.
