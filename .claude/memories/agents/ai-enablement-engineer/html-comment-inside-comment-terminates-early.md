---
id: html-comment-inside-comment-terminates-early
agent: [ai-enablement-engineer]
trigger: [HTML comment header block, embedding another <!-- --> inside outer comment text]
rule: When adding prose inside a file whose header is itself an HTML `<!-- ... -->` block, never embed another literal `<!-- ... -->` inside that same outer comment's text.
evidence: [NA-51]
uses: 0
status: active
---

## Why

Caught in a first draft describing a mechanism ("...recorded in a `<!-- declined: <type> -->`
comment line...") as prose inside an outer header comment. Fix: describe the mechanism in plain
words ("recorded — see the convention below") and never reproduce another HTML comment's literal
delimiters inside the text of a comment that's still open.
