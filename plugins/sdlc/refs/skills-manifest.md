# Skills Manifest — `.claude/project/skills.json`

This ref defines the format and update rules for the project-scoped skills file that `/init`
writes to `.claude/project/skills.json`. The file is **committed to the repository** (not
git-ignored) so every teammate who runs `/init` starts with the same skill set.

## Principles

1. Skills are loaded at the step that needs them, by the agent that needs them, never upfront.
2. One manifest. `.claude/project/skills.json` says which skills exist, which agents use them, and
   when. Agent overrides stop listing skills.
3. The plugin ships its own contract rows (the skills its templates and gates depend on) in the
   same schema; the repo's rows are merged over them by name, repo wins.
4. Verify artefacts, not loads. A spec is checked against the spec template, a commit against the
   conventional format, a plan against the plan template. `Skills loaded:` stays as information and
   is never the thing that passes or fails a return.
5. Nothing in an agent file names a repo skill. The dispatch prompt carries the rows.

---

## File location

```
.claude/project/skills.json
```

This path is the canonical location. All references in `/init` and the playbooks use exactly this
path. Do not abbreviate, alias, or move it.

---

## JSON schema (v2)

```json
{
  "version": 2,
  "skills": [
    {
      "name": "golang-testing",
      "source": "custom",
      "addedBy": "init",
      "agents": ["platform-engineer"],
      "required": true,
      "when": {
        "paths": ["backend/**"],
        "mode": [],
        "step": "before writing or changing a test"
      }
    }
  ]
}
```

### Field definitions

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `version` | `number` | yes | Schema version. `2` for files written by this version of the plugin; `1` is still read (see v1 files). |
| `skills` | `array` | yes | Ordered list of skill rows. Empty array `[]` is valid. |
| `skills[].name` | `string` | yes | Skill identifier, case-sensitive. Rows merge by this name. |
| `skills[].source` | `"suggested" \| "custom" \| "plugin"` | yes | `suggested` — recommended by `/init` from the detected stack. `custom` — typed by the user, or added by hand. `plugin` — a plugin contract row; only appears in `refs/skills-contract.json`. |
| `skills[].addedBy` | `string` | yes | The agent name or literal `"user"` that added the row. `/init` sets `"init"`; the plugin's own rows use `"plugin"`. |
| `skills[].agents` | `string[]` | no | Agent names from `plugins/sdlc/agents/*.md`, plus the reserved `qa-reviewer` (the QA reviewer dispatch, which is not an agent file). May be empty; empty (or absent) means tracked only, never injected. An unknown name is a malformed manifest. |
| `skills[].required` | `boolean` | no, default `true` | Wording only. `true` → "invoke before <step>"; `false` → "available; invoke if <step> applies". Neither is verified by set coverage. |
| `skills[].when` | `object` | no | Filters, all keys optional; absent means always, for the agents listed. |
| `skills[].when.paths` | `string[]` | no | Globs matched against the paths the dispatch passes (`--paths`). A dispatch path matches a glob when it is inside it or is a directory that contains it. No `--paths` given → path-gated rows match (conservative). |
| `skills[].when.mode` | `string[]` | no | Agent modes (`draft\|plan\|final`, `decompose\|triage\|design-revision`, `analyze\|story`, `sync\|release\|seed\|audit\|seed-adr\|distill`, …). Matches when the dispatch `--mode` is listed; a mode-gated row never matches a dispatch with no `--mode`. |
| `skills[].when.step` | `string` | no | A phrase shown to the agent as the point of use ("before writing or changing a test"). Never a filter. |

Other keys on a row (for example `note`) are ignored by the resolver and preserved by `/init`.

---

## Resolving a dispatch — `scripts/skills-for.sh`

```
skills-for.sh <agent> [--mode <m>] [--paths <glob,glob,...>] [--manifest <path>] [--contract <path>] [--print-prompt]
```

- Reads the plugin contract rows (`refs/skills-contract.json`) and the repo manifest, merges them by
  `name` (the repo row replaces the contract row entirely, including its `agents`), and prints one line per
  row that matches the agent, mode and paths: `SKILL=<name> REQUIRED=yes|no STEP=<phrase or ->`.
- `--print-prompt` prints the block a playbook or command pastes into a dispatch prompt instead:

  ```
  Skills for this dispatch (invoke each with the Skill tool at the step named, never earlier):
  - <name> — <required: before <step> | optional: if <step> applies>
  ```

- Empty output and exit 0 when nothing matches. Exit 2 on a malformed manifest (bad JSON, `version`
  other than 1 or 2, unknown agent name) or contract, with a one-line reason on stderr.
- The caller pastes the output into the dispatch prompt; the agent invokes each skill with the Skill
  tool at the step it names.

### Plugin contract rows

`refs/skills-contract.json` ships with the plugin, uses the same schema, and holds the skills the
plugin's own templates and gates depend on (`writing-specs`, `conventional-commit`, `acli`, ...). To
add one, append a row there with `"source": "plugin"` and `"addedBy": "plugin"`, name only agents
the plugin ships, and give it a `step` so the agent knows when to invoke it. A repo overrides a
contract row by writing a row with the same `name` in its own manifest.

### v1 files

A v1 file (`"version": 1`, rows with only `name`, `source`, `addedBy`) is read as tracked-only rows:
nothing is injected from it, and `skills-for.sh` prints
`WARN: skills.json is v1 — run /sdlc:init to upgrade` on stderr. Contract rows still apply.

---

## Write rules

### First write (new repo)

Write the full object from scratch. `agents` comes from the skill's `domains` in
`refs/skills-map.yml` (intersected with the active agents); `when` comes from its optional
`dispatch:` block (`paths`, `mode`, `step`), `{}` when absent; `required` is `true`. A custom skill
typed by the user gets every active domain engineer as `agents` and `when: {}`. Example for a
TypeScript + Hono repo that accepted the suggested `hono-api` skill and added a custom `my-deploy`
skill:

```json
{
  "version": 2,
  "skills": [
    {
      "name": "hono-api",
      "source": "suggested",
      "addedBy": "init",
      "agents": ["platform-engineer"],
      "required": true,
      "when": {}
    },
    {
      "name": "my-deploy",
      "source": "custom",
      "addedBy": "init",
      "agents": ["platform-engineer"],
      "required": true,
      "when": {}
    }
  ]
}
```

### Re-init / merge write (file already exists, v2)

**Never replace the existing file.** Instead:

1. Read the existing `skills.json`.
2. For each skill in the newly confirmed list:
   - If a skill with the same `name` already exists → leave the existing entry unchanged.
   - If the skill is not yet present → append a new entry.
3. Write the merged result back.

This union behaviour ensures a teammate running `/init` on an existing repo does not lose skills
another teammate added, and does not create duplicates.

### v1 → v2 upgrade (re-init on a v1 file)

For each row in the v1 file:

1. `agents` = every override (`.claude/project/agents/<agent>.md`) whose `## Project skills` section
   lists the name (empty when none does, which makes the row tracked only).
2. `required: true`, `when: {}`.
3. Keep `name`, `source`, `addedBy` and any other key unchanged.

Print the inferred rows for confirmation (the same merge/confirm flow as any re-init write). After
confirmation, set `"version": 2`, write the file, delete the `## Project skills` section from each
override, and leave one line in each override pointing at the manifest:
`Skills for this agent are listed in .claude/project/skills.json.`

### Removal

Removing a skill from the manifest is a manual operation. The `/init` command never removes
entries — it only adds. To remove a skill, edit `.claude/project/skills.json` directly and delete
the entry.

---

## Teammate re-run behaviour

When `/init` runs on a repo where `.claude/project/skills.json` already exists, it reads the file
before presenting the skill-suggestion picker (Step 3.5 in `init.md`). Skills whose `name` is
already listed in the manifest are **pre-selected** in the multi-select picker so the teammate sees
them as already-installed defaults. The teammate may:

- Leave them selected → they remain in the manifest (no-op).
- Deselect them → they remain in the manifest unchanged (removal is always manual).
- Select additional skills → those are appended under the merge rules above.

This ensures the suggestion UX never silently drops installed skills regardless of teammate input.

---

## Install

The manifest records which skills exist; recording a name is **not** an install — the skill must also
be made discoverable to the Skill tool. `/init` Step 4f does that install via one of three paths,
depending on whether the skill is published:

- **Direct source** (its `refs/skills-map.yml` entry declares `source`, optionally `path`/`ref`) →
  `/init` downloads the real skill content from that exact location into `.claude/skills/<name>/`.
- **Marketplace plugin** (entry declares `plugin`/`marketplace`, no `source`) → `/init` installs the
  providing plugin at project scope (`claude plugin install … --scope project`); the plugin owns the
  skill content, so **no `.claude/skills/<name>/SKILL.md` is written**.
- **No source declared** (custom / project-convention skills) → `/init` scaffolds
  `.claude/skills/<name>/SKILL.md` locally (skip-if-exists, so re-running never clobbers a
  hand-authored skill).

A row naming a skill with neither an installed providing plugin nor an on-disk `SKILL.md` is a
tracked-but-uninstalled skill: invisible to agents. `/init` writes the rows (Step 4d) and performs
the matching install (Step 4f) together so they never drift.
