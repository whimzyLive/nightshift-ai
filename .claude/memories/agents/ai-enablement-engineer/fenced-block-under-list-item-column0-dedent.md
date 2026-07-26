---
id: fenced-block-under-list-item-column0-dedent
agent: [ai-enablement-engineer]
trigger: [markdown fence nested under a numbered list item, quad-backtick shatter, prettier corrupts a fenced code block]
rule: When a fenced code block sits nested under a numbered/bulleted list item (e.g. an `acli --body "..."` block), dedent the ENTIRE block.
evidence: [NA-25, NA-27, NA-56, NA-57, NA-62]
uses: 0
status: active
---

## Why

Prettier's remark-based Markdown parser requires every line inside a fence nested in a list item
(including blank-line-separated continuations) to satisfy the item's content indentation — a
mismatch breaks the parser's list-item/fence association at parse time, causing a "quad-backtick
shatter" that no post-hoc `<!-- prettier-ignore -->` can fix (ignore comments only suppress
re-printing of already-correctly-parsed nodes). Column-0 dedent removes all ambiguity so the parser
leaves the block untouched. Two follow-on traps: (1) dedenting only the fence but leaving the
_following_ prose/bullets indented is itself non-idempotent — dedent the whole remaining
list-item continuation, not just the fence; (2) a column-0 dedent can silently break list-item
continuity for the _next_ numbered step (it becomes a structurally separate list) — if the plan
literally shows a column-0 fence at a specific insertion point, match its whitespace exactly rather
than reflowing for local consistency, since the plan's authors may have already reasoned through
this. Always verify with a real two-pass `prettier --write` (see
`prettier-idempotency-verification-protocol`), not a single `--check`, since first-write corruption
is common and a second-pass `(unchanged)` does not by itself prove no corruption happened on pass one.
