---
id: collapse-conditionally-irrelevant-hook-dep-to-stable-value
agent: [web-engineer]
trigger: [useEffect dep only relevant in one branch, inView added to a run-once effect deps, terminal restarts on scroll]
rule: "A `useEffect` dependency that's only sometimes semantically relevant can't be conditionally included in the deps array, but can be replaced with a value that's provably stable when irrelevant."
evidence: [NA-69]
uses: 0
status: active
---

## Why

Adding a shared hook's viewport/`inView` signal to a run-once effect's deps turns it into a
re-runs-on-scroll effect for every consumer that didn't opt into the viewport feature — gate it
behind the feature flag so consumers that didn't opt in keep run-once semantics.
