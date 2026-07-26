---
id: tail-generated-doc-for-artifact-tags
agent: [knowledge-engineer]
trigger: [generating an ADR, writing a new doc via Write tool, committing a generated document]
rule: Before committing any freshly-generated doc, `tail -3` the file to check for stray generation/markup artifacts (e.g. a trailing `</content>` tag).
evidence: [NA-73, NA-75]
uses: 0
status: active
---

## Why

An ADR shipped with a stray `</content>` wrapper as its last line, twice — once on NA-73 and again
on NA-75 despite the prior learning being in context. Artifact tags at end-of-file survive prettier
and index regen unnoticed; always `tail -3` a freshly-Written generated doc and run
`prettier --check` directly on it (see `prettier-check-must-run-directly-not-piped`) before treating
a doc-generation task as done.
