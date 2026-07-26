---
id: never-wrap-markdown-heading-across-lines
agent: [ai-enablement-engineer]
trigger: [long markdown heading, ## or ### heading wrapped physically, prettier proseWrap preserve]
rule: A `##`/`###` markdown heading is only the text on its own physical source line.
evidence: [NA-51]
uses: 0
status: active
---

## Why

`prettier --write` (`proseWrap: preserve` in this repo) does NOT rejoin a wrapped heading for you —
this is a self-inflicted, Prettier-invisible defect. It happened to this very memory file's own
previous entry once, corrupting its own section heading.
