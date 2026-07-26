---
id: llms-txt-consistency-scripted-check
agent: [knowledge-engineer]
trigger: [verifying llms.txt, frontmatter consistency check, docs audit reference-integrity]
rule: Verify `llms.txt` by scripting a check (parse each `title — description — link` line, load the linked page's frontmatter, assert exact string equality) rather than manually spot-checking entries.
evidence: [PR#155]
uses: 0
status: active
---

## Why

Reusable pattern for any future audit's `llms.txt` verification pass — cheaper and more reliable
than manual spot-checks; also confirms zero orphaned pages by checking every `docs/**` frontmatter
file that should be public is accounted for.
