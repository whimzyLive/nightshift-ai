---
id: plugins-sdlc-only-change-no-nx-tasks-expected
agent: [ai-enablement-engineer, platform-engineer]
trigger: [pnpm nx affected -t test, pnpm nx format:check, plugins-only change, no tasks were run]
rule: Treat `pnpm nx affected -t test --base=remotes/origin/develop` / `pnpm nx format:check` reporting "No tasks were run" / clean for a `plugins/sdlc/**`-only or `plugins/gtm/**`-only change as the.
evidence: [NA-52, NA-54, NA-55, NA-57, NA-60, NA-61, NA-62, NA-63, NA-65, NA-68]
uses: 0
status: active
---

## Why

No Nx project owns `plugins/sdlc/**`/`plugins/gtm/**` (confirmed repeatedly across many
plugin-authoring stories), so this repo's Nx graph has nothing to run for a docs/instructions-only
change under those paths. Don't mistake a clean "no tasks" affected-scoped result for a bug or a
missed gate.
