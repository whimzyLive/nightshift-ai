---
id: plugin-json-version-bump-every-content-commit
agent: [ai-enablement-engineer]
trigger: [shipping new plugin content, plugins/sdlc/.claude-plugin/plugin.json, nx release version bump]
rule: Every commit shipping new content under `plugins/<plugin>/` must bump that plugin's `.claude-plugin/plugin.json` version in the same commit.
evidence: [NA-44, NA-48, NA-54, NA-58, NA-60, NA-62, NA-65, NA-68, NA-91]
uses: 1
status: active
---

## Why

Pinned consumers won't see a new skill or an agent's updated instructions otherwise. One story
(NA-53) silently skipped the bump and a later story initially treated that gap as a "more recent
precedent" to match — that reasoning was wrong: a documented hard rule one sibling story skipped is
a known gap in that story, not a new counter-rule superseding the original. The rule wins; treat the
sibling's gap as a defect to flag/backfill, never as a new precedent to extend.

Superseded scope note: since NA-63, `nx release version -p sdlc` (or `-p gtm`) is the actual owner
of this bump post-merge — a feature/impl/fix PR should NOT hand-bump the version at all; leave it at
develop's value and let the post-merge release step compute it from conventional commits. This
supersedes the "bump it yourself in the PR" mechanic above while the underlying "every content
change eventually gets a real version bump" intent stays true.
