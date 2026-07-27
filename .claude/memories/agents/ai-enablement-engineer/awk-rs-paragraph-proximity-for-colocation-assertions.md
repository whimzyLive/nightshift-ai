---
id: awk-rs-paragraph-proximity-for-colocation-assertions
agent: [ai-enablement-engineer]
trigger: [tightening a text-presence test into a proximity test, prompt-document regression test, STOP instruction co-located with a token]
rule: When a regression test must prove two phrases co-locate in a prose document, split on blank lines via `awk -v RS=""` and require both match in one paragraph, not just anywhere in the file.
evidence: [NA-78]
uses: 0
status: active
---

## Why

A bare `grep -qi A file && grep -qi B file` proves presence-anywhere, which can't tell a
well-placed clause from two unrelated mentions elsewhere in the doc. A same-line or fixed N-line
window is brittle against prose LINE-WRAP reflow (wrapped sentences span several physical lines).
Markdown's own paragraph boundary (blank line) survives line-wrap reflow, so `awk -v RS=""`
paragraph mode is a more robust proximity check than either alternative — confirmed by
mutation-testing both a deletion (case fails) and a restore (case passes) against
`plugins/sdlc/commands/refine-feature.md`'s STOP clause. Caveat: it does NOT survive a legitimate
edit that splits one clause across two separate paragraphs — that produces a false FAIL, so this
technique assumes the co-located instruction is intended to stay one paragraph.
