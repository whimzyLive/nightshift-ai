---
id: run-skill-quick-validate-on-every-skill-edit
agent: [ai-enablement-engineer]
trigger: [new SKILL.md, editing a plugin-bundled skill, skill description length]
rule: Run `plugins/sdlc/skills/skill-creator/scripts/quick_validate.py plugins/sdlc/skills/<name>` on every new/edited `SKILL.md` in this plugin as a matter of course.
evidence: [NA-58]
uses: 0
status: active
---

## Why

A skill description written at 1162 chars (over the 1024-char validator limit) passed silently
through authoring — nothing surfaced the limit until QA ran the validator explicitly. It also
enforces `name` kebab-case/length, frontmatter allowed-keys, and "no angle brackets in description"
in one pass. Run it from the repo root:
`python3 plugins/sdlc/skills/skill-creator/scripts/quick_validate.py plugins/sdlc/skills/<name>`.
