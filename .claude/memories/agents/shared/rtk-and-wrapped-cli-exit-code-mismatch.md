---
id: rtk-and-wrapped-cli-exit-code-mismatch
agent: [ai-enablement-engineer, platform-engineer]
trigger: [pnpm exec tsc, pnpm exec prettier --check, rtk proxy hook, wrapped command false success]
rule: "When a wrapped command's output and exit code visibly disagree (e.g. under the user's `rtk` proxy hook), reach for the raw binary or `rtk proxy <cmd>` immediately rather than debugging the mismatch."
evidence: [NA-63, NA-57, NA-62]
uses: 0
status: active
---

## Why

`pnpm exec tsc ...` printed `TypeScript: No errors found` but still exited 1; `pnpm exec prettier
--check <file>` printed a misleadingly generic "All files formatted correctly" while still exiting
1 (or exiting 0 while a real issue existed). Both are wrapper artifacts, not signals about the file
— confirmed by re-running the raw binary and getting a trustworthy, matching exit code/output.
