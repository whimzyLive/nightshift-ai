---
id: no-story-reference-in-permanent-artifact
agent: [ai-enablement-engineer]
trigger: [writing plugin ref prose, explaining why a capability is deferred, drafting a new paragraph in a permanent doc]
rule: Never write "this story ships...", "this PR...", or "current story" inside a permanent plugin artifact (agent def, ref, skill, README).
evidence: [NA-25, NA-27, NA-43, NA-51]
uses: 0
status: active
---

## Why

This exact anti-pattern recurred across multiple stories, including a case where the author fixed
it once elsewhere in the same PR and then reintroduced it in a new paragraph moments later — the
instinct to explain "why this doesn't do X yet" by naming the current story is strong and
recurring. Actively grep any newly-authored paragraph in a permanent artifact for "this story" /
"this PR" / "current story" before considering it done.
