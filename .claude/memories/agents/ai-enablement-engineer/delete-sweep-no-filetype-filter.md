---
id: delete-sweep-no-filetype-filter
agent: [ai-enablement-engineer]
trigger: [deleting repo artifact, moving repo artifact, reference sweep, agent def removal]
rule: 'When deleting or relocating any repo artifact, grep the entire tree with no file-type include filters — non-code surfaces (marketing TS, configs) link plugin paths too.'
evidence: [NA-75]
uses: 0
status: active
---

## Why

NA-75's sweep used `--include='*.md' --include='*.sh'` and missed two TypeScript marketing surfaces linking the deleted agent defs, producing would-be public 404s caught only in QA review.
