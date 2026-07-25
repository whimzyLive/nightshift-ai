---
id: animatepresence-mode-wait-needs-await-for-post-mount-transitions
agent: [web-engineer]
trigger: [AnimatePresence mode=wait live post-mount state change, existing synchronous fireEvent assertion breaks]
rule: Wrapping a live, post-mount state change (e.g. a hover `active` state) in `AnimatePresence mode="wait"` introduces a real async gap before the new keyed child's content lands.
evidence: [NA-69]
uses: 0
status: active
---
