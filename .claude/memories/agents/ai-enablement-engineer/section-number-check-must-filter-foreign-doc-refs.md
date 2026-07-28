---
id: section-number-check-must-filter-foreign-doc-refs
agent: [ai-enablement-engineer]
trigger: [writing a cross-file section-number consistency check, matching bare §N references across split slice files, a §N regex also matches a different document's own numbering]
rule: A cross-file "§N" consistency check must skip a match whose nearest preceding filename qualifier names a DIFFERENT document — the same section number legitimately collides across unrelated files.
evidence: [NA-79]
uses: 1
status: active
---

## Why

`docs-pipeline-slicing.test.sh`'s new slice-consistency case (Case 7) initially flagged
`` `refs/adr-pipeline.md` §10 `` and `` `refs/adr-pipeline.md` §3a `` inside `docs-pipeline-core.md`
and `docs-pipeline-audit.md` as bare cross-slice references into `docs-pipeline-release.md` §10 and
`docs-pipeline-core.md` §3 — false positives. Those `§N` tokens belong to `adr-pipeline.md`'s own,
entirely separate numbering scheme; the digits collided with the docs-pipeline registry's numbering
by coincidence, not by reference. Fixed by requiring the check to look at the nearest preceding
backtick-quoted `` `*.md` `` filename within a tight window before the match — if that filename
names a different document, the `§N` is scoped to that document's own numbering and is skipped
entirely, never treated as an unqualified docs-pipeline pointer.
