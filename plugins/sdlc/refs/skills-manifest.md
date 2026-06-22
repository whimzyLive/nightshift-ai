# Skills Manifest — `.claude/project/skills.json`

This ref defines the format and update rules for the project-scoped skills tracking file that
`/init` writes to `.claude/project/skills.json`. The file is **committed to the repository** (not
git-ignored) so every teammate who runs `/init` starts with the same skill set.

---

## File location

```
.claude/project/skills.json
```

This path is the canonical location. All references in `/init` and agent overrides use exactly
this path. Do not abbreviate, alias, or move it.

---

## JSON schema

```json
{
  "version": 1,
  "skills": [
    {
      "name": "string — the skill identifier as listed in the agent override",
      "source": "suggested | custom",
      "addedBy": "string — the agent or user session that added this entry"
    }
  ]
}
```

### Field definitions

| Field | Type | Required | Description |
| ----- | ---- | -------- | ----------- |
| `version` | `number` | yes | Schema version. Always `1` for files written by this version of the plugin. |
| `skills` | `array` | yes | Ordered list of tracked skill entries. Empty array `[]` is valid. |
| `skills[].name` | `string` | yes | Skill identifier — must match the name listed in `.claude/project/agents/<agent>.md`. Case-sensitive. |
| `skills[].source` | `"suggested" \| "custom"` | yes | `suggested` — the skill was recommended by `/init` based on the detected stack. `custom` — the user typed a skill name not in the suggestion list. |
| `skills[].addedBy` | `string` | yes | The agent name (e.g. `platform-engineer`) or literal `"user"` that added this entry. `/init` always sets this to `"init"`. |

---

## Write rules

### First write (new repo)

Write the full object from scratch. Example for a TypeScript + Hono repo that accepted the
suggested `hono-api` skill and added a custom `my-deploy` skill:

```json
{
  "version": 1,
  "skills": [
    { "name": "hono-api", "source": "suggested", "addedBy": "init" },
    { "name": "my-deploy", "source": "custom", "addedBy": "init" }
  ]
}
```

### Re-init / merge write (file already exists)

**Never replace the existing file.** Instead:

1. Read the existing `skills.json`.
2. For each skill in the newly confirmed list:
   - If a skill with the same `name` already exists → leave the existing entry unchanged.
   - If the skill is not yet present → append a new entry.
3. Write the merged result back.

This union behaviour ensures a teammate running `/init` on an existing repo does not lose skills
another teammate added, and does not create duplicates.

### Removal

Removing a skill from the manifest is a manual operation. The `/init` command never removes
entries — it only adds. To remove a skill, edit `.claude/project/skills.json` directly and delete
the entry, then remove the corresponding line from the agent override file.

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

## Agent override integration

Each domain agent override (`.claude/project/agents/<agent>.md`) lists skills by name in its
`## Project skills` section. The names must match `skills[].name` entries in
`.claude/project/skills.json` exactly. `/init` populates the override's skill list from the
manifest entries whose domain relevance matches the agent — platform-facing skills go into
`platform-engineer.md`, frontend skills into `web-engineer.md`, and so on.

The override file is the runtime source of truth (agents invoke skills by reading the override);
`skills.json` is the sharing and deduplication source of truth (teammates read it to know what is
installed). Both must stay in sync — `/init` writes them together.
