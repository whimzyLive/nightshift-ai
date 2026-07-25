---
id: flag-dangling-xref-outside-write-scope
agent: [knowledge-engineer]
trigger: [dangling internal cross-reference found outside own write scope, plugins ref file drift]
rule: "When an audit finds a dangling internal cross-reference inside a file outside knowledge-engineer's write scope, flag it in the report rather than silently fixing or ignoring it."
evidence: [PR#155]
uses: 0
status: active
---

## Why

A rewrite of `docs-pipeline.md` §3 deleted a subsection while leaving 7 live references to it — this
doesn't block or change audit's own output (audit doesn't audit the plugin's own ref files), but it's
worth flagging to whoever next touches the file, since the deletion looked like a rebase/merge
artifact rather than a deliberate removal.
