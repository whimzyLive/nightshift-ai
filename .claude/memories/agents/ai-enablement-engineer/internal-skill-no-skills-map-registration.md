---
id: internal-skill-no-skills-map-registration
agent: [ai-enablement-engineer]
trigger: [adding an internal agent-consumed skill, writing-docs skills-map.yml entry, README update timing]
rule: 'An internal, agent-consumed plugin skill needs no `skills-map.yml` entry (only for skills suggested to consumers) and no README update in the commit that ships it ahead of its consumer.'
evidence: [NA-58]
uses: 0
status: active
---

## Why

Confirmed via `git show f4250c4 --stat` (NA-44's commit) that a net-new plugin-bundled internal
skill touches only the `SKILL.md` + memory file when shipped ahead of its consumer; the README
picks up the full pipeline prose only in a later, separate commit once the full consuming command
exists.
