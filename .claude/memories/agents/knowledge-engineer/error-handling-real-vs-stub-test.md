---
id: error-handling-real-vs-stub-test
agent: [knowledge-engineer]
trigger: [error handling section scan, aggregating error tables, casing of Error Handling heading]
rule: When scanning for real "Error Handling" sections, check whether the section has its own concrete rows (not hedge language) and scan BOTH `## Error Handling` and `## Error handling` casings.
evidence: [PR#155]
uses: 0
status: active
---

## Why

A file with its own concrete rows counts as real even if it also says "this mirrors the spec" or
partially defers elsewhere for other content — don't over-index on a trailing hedge sentence, check
whether the table itself has rows. Separately, this repo genuinely mixes `## Error Handling`
(agents, title-case) and `## Error handling` (commands/refs, sentence-case) — a scan keyed on one
exact casing silently drops half the real sections regardless of how exhaustive its file-glob is.
