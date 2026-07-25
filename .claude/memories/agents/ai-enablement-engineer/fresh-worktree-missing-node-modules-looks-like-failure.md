---
id: fresh-worktree-missing-node-modules-looks-like-failure
agent: [ai-enablement-engineer]
trigger: [ERR_PNPM_RECURSIVE_EXEC_FIRST_FAIL lint-staged not found, first commit attempt in fresh worktree]
rule: '`ERR_PNPM_RECURSIVE_EXEC_FIRST_FAIL … "lint-staged" not found` on a first commit attempt in a fresh worktree means `node_modules` is missing entirely, not that the commit content is wrong.'
evidence: [NA-27]
uses: 0
status: active
---
