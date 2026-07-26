---
id: unqualified-table-row-can-swallow-new-exemption
agent: [ai-enablement-engineer]
trigger: [manifest absent silent no-op row, adding a manifest-exempt mode next to manifest-gated ones]
rule: When a story adds a new manifest-EXEMPT route next to existing manifest-GATED ones, re-read every unqualified/table-wide error row for accidental scope creep onto the new exemption.
evidence: [NA-57]
uses: 0
status: active
---

## Why

`commands/docs.md`'s error table's first row read "manifest absent → Silent no-op" with no mode
qualifier — a leftover from when all modes shared one manifest gate. Once new manifest-exempt modes
became live, that same unqualified row is the first match a reader (or implementer) would apply to
them too, reintroducing exactly the "collapse a distinct path into a benign no-op" defect class the
whole epic was closing. This is a semantic scope gap in unchanged pre-existing prose, not a residual
string — no string-grep verification catches it.
