---
id: view-model-should-carry-boolean-not-target-technology-string
agent: [web-engineer]
trigger: [CtrlGate.anim field baked CSS animation shorthand into a derived view-model, migrating to Motion]
rule: "Don't carry a target-technology-specific value through a pure derivation function when the renderer can trivially compute the same branch from a plain boolean."
evidence: [e165158]
uses: 0
status: active
---
