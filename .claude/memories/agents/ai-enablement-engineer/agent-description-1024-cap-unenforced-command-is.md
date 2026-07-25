---
id: agent-description-1024-cap-unenforced-command-is
agent: [ai-enablement-engineer]
trigger: [agent frontmatter description length, 1024-char cap, command frontmatter cap]
rule: This repo's agent-file frontmatter `description` field is NOT actually bounded at 1024 chars in practice (several pre-existing agent descriptions already exceed it, unenforced by any script).
evidence: [NA-55, NA-57]
uses: 0
status: active
---

## Why

`agents/knowledge-engineer.md`'s description was already over 1024 chars before a story touched it,
confirmed via `git show HEAD:<file>`; no script in `plugins/sdlc/scripts/` validates agent
description length (only `skill-creator/scripts/quick_validate.py`, which is `SKILL.md`-only and
refuses any other filename). Command frontmatter genuinely does enforce the cap — `docs.md`'s own
description had to be trimmed twice to fit.
