---
id: gtm-plugin-independent-no-sdlc-artifact-dependency
agent: [ai-enablement-engineer]
trigger: [gtm plugin reaching for project-context.md, gh pr create --base develop hardcoded, consumer repo has no sdlc artifact]
rule: Any `plugins/gtm` instruction that reaches for an sdlc-owned artifact (`.claude/project/project-context.md`, its Base branch row, etc.) needs an explicit "this file may not exist" branch, not a.
evidence: [NA-7]
uses: 0
status: active
---

## Why

Hardcoding `gh pr create --base develop` meant every consumer repo whose default branch is `main`
would silently open zero PRs. Fixed by resolving the base branch at runtime with
`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, treating project-context's
`Base branch` token as an optional override only when that file happens to exist.
