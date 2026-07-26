---
id: claude-plugin-root-pointer-in-override-publish-lag
agent: [ai-enablement-engineer]
trigger: [CLAUDE_PLUGIN_ROOT pointer in a project override, adding a plugin refs/ file referenced by an override]
rule: "`${CLAUDE_PLUGIN_ROOT}/refs/<file>.md` pointer syntax works fine inside a repo-owned project override file, but resolves to the INSTALLED plugin cache, not the repo's `plugins/sdlc/` source."
evidence: [NA-48]
uses: 0
status: active
---

## Why

A repo-owned override merges live immediately, but between merge and reinstall the override's
pointer dangles (file-not-found) and the rule does not load. Any story adding a plugin `refs/` file
referenced by a repo-owned override must flag the republish+reinstall as the go-live step in the PR
body — this is normal plugin publish/install lag, not a defect.
