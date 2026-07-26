---
id: verify-invisible-char-fix-via-python-repr-ord
agent: [web-engineer]
trigger: [non-breaking space vs regular space fix, visually indistinguishable before/after]
rule: "When a fix's before/after snippets are visually indistinguishable (e.g. a non-breaking space vs a regular space), verify the byte actually landed via a `python3` `repr()`/`ord()` check."
evidence: [PR#97]
uses: 0
status: active
---
