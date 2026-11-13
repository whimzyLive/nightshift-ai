# Extending nightshift — teach the agents your stack

You almost never fork nightshift. The agents are deliberately generic — you teach them your tech
stack from **your own repo**, through two project-tier files plus any skills you write. The generic
agents stay untouched and keep getting upstream updates.

Each domain agent, at startup, does this:

1. reads `.claude/project/project-context.md` (constants, tooling, the workspace→agent ownership table);
2. reads its **override** `.claude/project/agents/<agent>.md` for directory guides and rules.

Skills are not loaded at startup. The dispatching playbook or command runs
`plugins/sdlc/scripts/skills-for.sh <agent> --print-prompt` and pastes the result into the agent's prompt:
each applicable skill with the step at which to invoke it. The agent invokes it with the Skill tool at
that step, never earlier.

So extending an agent = **write a skill + add a row to the skills manifest.** Three steps.

## 1. Add a skill (your stack's know-how)

Drop it in your repo at `.claude/skills/<name>/SKILL.md`:

```markdown
---
name: my-orm
description: How we model entities, write migrations, and query with <your ORM>.
---

When writing data-access code in this project:

- Entities live in `src/db/entities/*.ts`; one file per entity.
- Every migration is generated, never hand-written: `npm run db:generate`.
- Always scope queries by `tenantId`. Never return cross-tenant rows.
```

Skills can be anything an agent should _pull in on demand_: an ORM convention, an API-routing
pattern, a design system, a deployment recipe. Skills from **any** installed plugin work too —
just reference them by name.

## 2. Bind the skill to agents (the manifest)

Add a row to `.claude/project/skills.json` (schema and merge rules: `plugins/sdlc/refs/skills-manifest.md`):

```json
{
  "version": 2,
  "skills": [
    {
      "name": "my-orm",
      "source": "custom",
      "addedBy": "user",
      "agents": ["platform-engineer", "database-administrator"],
      "required": true,
      "when": {
        "paths": ["src/db/**"],
        "step": "before changing an entity or a migration"
      }
    }
  ]
}
```

- `agents` — agent names from `plugins/sdlc/agents/`; empty means tracked only, never injected.
- `required` — wording only: `true` says "invoke before <step>", `false` says "invoke if <step> applies".
- `when` — all keys optional. `paths` globs are matched against the paths the dispatch passes; `mode` lists the agent
  modes the row applies to; `step` is the phrase shown to the agent as the point of use.
- The plugin ships its own rows (the skills its templates and gates depend on) in
  `plugins/sdlc/refs/skills-contract.json`. Yours are merged over them by `name`, so a row of the same name replaces the
  plugin's. To add a contract row to the plugin itself, append it there with `"source": "plugin"`.

Check what a dispatch will name with `bash plugins/sdlc/scripts/skills-for.sh platform-engineer --paths src/db/ --print-prompt`.

The override file keeps the rest of the contract the agent reads:

```markdown
# Platform Engineer — <your-project> bindings

## Directory guides (read before coding)

- src/db/CLAUDE.md
- src/api/CLAUDE.md

## Ownership

- owns: src/api/, src/db/
- never: src/web/ (web-engineer)
- runs after: database-administrator · before: web-engineer

## Tech rules

- <Framework + runtime>, TypeScript strict, no `any`, kebab-case files.
- <Any "always do X / never do Y" your codebase enforces.>

## Local dev (tokens from project-context Tooling)

- Build: `<your build cmd>` · Test: `<your test cmd>` · never run cloud deploys.
```

An override that still has a `## Project skills` section is no longer read for skills. Re-run `/sdlc:init`: on a v1
`skills.json` it moves those lists into manifest rows (printing them for confirmation first) and removes the sections.

## 3. Declare ownership + tooling once (project-context)

In `.claude/project/project-context.md`, the **workspace→agent** table is the single source of
truth for who owns what, and the **Tooling** rows define the quality gate every agent runs:

```markdown
## Workspace → agent

| Path     | Owner             |
| -------- | ----------------- |
| src/api/ | platform-engineer |
| src/web/ | web-engineer      |

## Tooling

| Typecheck | `npm run typecheck` |
| Test | `npm test` |
```

## Patterns

- **New tech, existing role** → add a skill + a manifest row naming that role. (Most common.)
- **Same role, different conventions per repo** → just change the override and the manifest rows; the generic agent is reused as-is.
- **Activate a standby role** (mobile, sync, db) → mark it Active in project-context and give it an override.
- **A brand-new role** (e.g. `ml-engineer`) → fork the marketplace, add `agents/ml-engineer.md` to the plugin, and `/plugin marketplace update`. PRs for broadly useful roles are welcome.

> Rule of thumb: **project-specific knowledge → your repo's `.claude/` (skills + manifest + overrides + project-context). Generic role behavior → the plugin.** Keep that line clean and upgrades never fight your customizations.

## A note on plugin versions

Never hand-edit a plugin's `.claude-plugin/plugin.json` `version` field. It's managed by
`nx release`, driven by your conventional commits — see [CONTRIBUTING.md's "Releasing"
section](CONTRIBUTING.md#releasing) for the commit contract, the release commands, and the
one-time baseline-tag backfill.
