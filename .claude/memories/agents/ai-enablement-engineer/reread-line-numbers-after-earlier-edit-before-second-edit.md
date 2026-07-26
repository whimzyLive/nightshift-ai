---
id: reread-line-numbers-after-earlier-edit-before-second-edit
agent: [ai-enablement-engineer]
trigger: [prettier reflow shifts line numbers mid-session, review finding cites pre-prettier line numbers]
rule: Prettier's per-file reflow (e.g. table column realignment after a cell edit) can shift a fix's target line numbers between what you read and what actually gets committed.
evidence: [NA-52]
uses: 0
status: active
---
