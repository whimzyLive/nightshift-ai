---
id: prefer-folding-into-existing-step-over-renumbering
agent: [ai-enablement-engineer]
trigger: [dense cross-file step-N citations, adding a step's worth of new behavior to a numbered doc set]
rule: When a fix must add a step's worth of new behavior to an already-numbered, cross-referenced document set, prefer folding it into the front of the most relevant existing step over inserting a new.
evidence: [NA-7]
uses: 0
status: active
---

## Why

A dense mesh of cross-file "step N" citations (command step → agent step → ref step, each file
numbering independently) goes stale the moment any numbered step gets inserted or reworded. Still
always finish with a blind `grep -n 'step[- ][0-9]'` across every touched file and manually verify
each hit — several citations can be wrong from the original authoring (not the renumbering), since
cross-file references are the ones most likely to be wrong on first authoring (no single file shows
both numberings side-by-side).
