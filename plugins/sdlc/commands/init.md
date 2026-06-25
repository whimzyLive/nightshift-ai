---
description: One-command onboarding for a new repo — interactively scaffolds .claude/project/project-context.md, the active agents' override files, the plugin-root marker, and the project skills manifest, after gating on the gh/acli prerequisites and walking you through acli authentication. Scans the repository stack to pre-fill defaults and suggest relevant skills. Safe to re-run against an already-initialised repo (merge/confirm flow). Ends with a post-init checklist of the Jira custom fields you must configure by hand.
---

Onboard **this repository** to nightshift SDLC. Walk the user through prerequisites, authentication,
and configuration, then write every file the plugin needs to run here. `$ARGUMENTS` is ignored —
`/init` is always interactive.

This command runs **in order**: a missing prerequisite must never leave half-written config, and
authentication is verified **before** any file is generated. Do the steps below top to bottom and
**STOP** at the first failure, surfacing an actionable message.

## Step 0 — Re-init guard

Before doing anything else, check whether `.claude/project/project-context.md` already exists:

```bash
[ -f ".claude/project/project-context.md" ] && echo "EXISTING=yes" || echo "EXISTING=no"
```

**If `EXISTING=no`** — proceed to Step 1 normally (fresh init).

**If `EXISTING=yes`** — do not overwrite. Instead:

1. Read the existing `.claude/project/project-context.md` to capture its current values.
2. Run the repo-detection procedure from `refs/repo-detect.md` (same scan as Step 2.5) to get fresh
   detected values.
3. Show the user a brief diff: which detected values differ from what is already stored.
4. Ask how to proceed:

   ```
   AskUserQuestion(
     header: "Existing config",
     question: "This repo is already initialised. How would you like to proceed?",
     multiSelect: false,
     options: [
       { label: "Keep existing",    description: "Stop now — no files will be changed." },
       { label: "Merge new findings", description: "Backfill any token the current template defines but the file is missing (prompting for new user-choice fields); keep everything already set." },
       { label: "Re-run full setup", description: "Walk through all prompts again and rewrite config (existing values offered as defaults)." }
     ]
   )
   ```

   - **Keep existing** → print a summary of what was found and **STOP** without writing any file.
   - **Merge new findings** → bring the existing file up to the current template **without
     disturbing values already set**, via a schema-backfill pass:
     1. Run Step 2.5 (re-detect) to refresh detected defaults.
     2. **Diff against the template schema.** Treat `refs/project-context-template.md` as the
        canonical set of sections/tokens `/init` is expected to write. For every token/section it
        defines that is **absent** from the existing `.claude/project/project-context.md`:
        - if the field has a **Step 3 prompt** (picker or free-text — e.g. Review agent, Review
          trigger, Lightweight threshold), **prompt for it now using that exact Step 3 mechanic**
          (same `header`/`options`), pre-filling the template default as the offered/selected default;
        - otherwise (a detection-only or static field) fill it from Step 2.5 or the template default,
          no prompt.

        This is the mechanism that auto-onboards **any newly introduced parameter**: when a future
        template adds a token, an existing repo that runs Merge picks it up here — prompted if it is a
        user choice, defaulted otherwise — instead of silently missing it.
     3. **Never touch values already present** — only missing tokens are added; existing values are
        kept verbatim (the detected-value diff from step 3 of this guard may still be offered for
        changed detections, as today).
     4. Jump to Step 4b (write the merged project-context), Step 4d (merge skills.json), Step 4e
        (ensure .tmp/ is gitignored), and Step 5.
   - **Re-run full setup** → continue to Step 1 with all existing values offered as pre-filled
     defaults in each prompt.

## Step 1 — Prerequisite gate (create nothing yet)

Both the `gh` (GitHub) and `acli` (Jira) CLIs are required for the ticket/PR integrations. Detect
them, and if **either** is missing, print the correct install command for the user's OS and **exit
immediately without creating any files**:

```bash
MISSING=""
command -v gh   >/dev/null 2>&1 || MISSING="$MISSING gh"
command -v acli >/dev/null 2>&1 || MISSING="$MISSING acli"
echo "OS=$(uname -s)"
echo "MISSING=${MISSING:-none}"
```

If `MISSING` is not `none`, resolve the install instructions for the detected OS and STOP:

- **macOS** (`uname -s` = `Darwin`): `brew install gh` · `brew tap atlassian/homebrew-acli && brew install acli`
- **Debian/Ubuntu** (`uname -s` = `Linux`): `gh` → see <https://github.com/cli/cli/blob/trunk/docs/install_linux.md>; `acli` → download from <https://developer.atlassian.com/cloud/acli/guides/install-acli/>
- **Other / unknown**: point at `gh` <https://cli.github.com/> and `acli` <https://developer.atlassian.com/cloud/acli/guides/install-acli/>

Tell the user exactly which of `gh` / `acli` is missing, give the matching command(s), and stop:

> Missing prerequisite(s): `<list>`. Install the above, then re-run `/init`. No files were created.

Only when **both** are present, continue.

## Step 2 — Verify acli authentication (before any write)

File generation must not begin until Jira auth is confirmed. Probe the current status:

```bash
acli jira auth status 2>&1 | tail -5
```

- **Authenticated** → continue to Step 2.5.
- **Not authenticated / error** → guide the user through login. Collect the **site** (e.g.
  `your-org.atlassian.net`), **email**, and an **API token** (from
  <https://id.atlassian.com/manage-profile/security/api-tokens>), then run the login and re-verify:

  ```bash
  acli jira auth login --site "<site>" --email "<email>" --token "<api-token>"
  acli jira auth status 2>&1 | tail -5
  ```

  If the re-verify still fails, **STOP** with an actionable error naming the likely cause (wrong
  site host, expired/incorrect token, or email mismatch) and tell the user to re-run `/init` after
  fixing it. Do **not** proceed to file generation on an auth failure.

## Step 2.5 — Repository scan (read-only, sets defaults)

Before prompting the user, scan the repository to detect the stack. Follow `refs/repo-detect.md`
exactly. This step is **read-only** — no files are written here. Store the seven detected values
for use as pre-filled defaults in Step 3:

```bash
# Run through each detection step in refs/repo-detect.md:
# Step 1 — package manager (lockfile precedence)
# Step 2 — language(s)
# Step 3 — framework
# Step 4 — test runner
# Step 5 — typecheck command
# Step 6 — runtime (version declaration)
# Step 7 — commit scopes (packages/ and apps/ subdirectory names)
```

After the scan, you will have (or empty strings for inconclusive signals):

| Variable | Detected value |
| -------- | -------------- |
| `DETECTED_LANG` | e.g. `TypeScript` |
| `DETECTED_FRAMEWORK` | e.g. `Hono` |
| `DETECTED_PM` | e.g. `pnpm` |
| `DETECTED_TEST` | e.g. `pnpm test` |
| `DETECTED_TYPECHECK` | e.g. `pnpm typecheck` |
| `DETECTED_RUNTIME` | e.g. `Node 20` (empty if no version declaration found) |
| `DETECTED_COMMIT_SCOPES` | e.g. `functions, config, web` (empty if no `packages/`/`apps/` dir) |

These values **pre-fill the matching Step-3 prompts** (the package-manager picker pre-selects the
detected option; the typecheck and test free-text fields display the detected command as the
suggested default). The user can still change every value — detection sets defaults, it does not
bypass the prompts.

Also check whether `.claude/project/skills.json` already exists and read it if so — you will need
it in Step 3.5:

```bash
[ -f ".claude/project/skills.json" ] && echo "SKILLS_EXIST=yes" || echo "SKILLS_EXIST=no"
```

## Step 3 — Collect configuration (one value at a time)

Prompt the user for each value **individually** — one question at a time, never batched into a wall
of prompts. Each field is **either** a picker **or** free text; the mechanics are mandatory, not a
suggestion (see *Prompt mechanics* below). Collect:

| Value | Notes |
| ----- | ----- |
| Project name | repo/display name, e.g. `acme-api` |
| Jira project key | uppercase, e.g. `ACME` (validate with `acli jira project view <KEY>`) |
| Jira site | the authenticated host from Step 2 (offer it as the default) |
| Base branch | the integration branch PRs target, e.g. `main` or `develop` |
| Package manager | `npm` / `pnpm` / `yarn` / `bun` / other — **pre-select `DETECTED_PM`** |
| Typecheck command | the project's typecheck — **default: `DETECTED_TYPECHECK`** (blank if none) |
| Test command | the project's test runner — **default: `DETECTED_TEST`** (blank if none) |
| Lightweight threshold | story points at/under which `/auto` skips spec+plan; default `3` |
| Active agents | the **domain** agents whose code lives in this repo (see below) |
| Review agent | who drives the `/loop` review-fix cycle — `claude-inline` (default), `github-copilot`, or `claude-superpowers` |
| Review trigger | when the loop requests/waits for review — `on-update` (default) / `on-create` / `none` |

### Prompt mechanics (mandatory — do not fall back to plain text for picker fields)

Every **finite-choice** field below MUST be asked with the `AskUserQuestion` tool (the native
selectable picker), with **exactly** the `header`, `question`, `multiSelect`, and `options` given.
`AskUserQuestion` always appends an "Other" escape, so options need not be exhaustive. The
free-text fields MUST be asked as plain questions (no picker — open values have no finite set).

**Picker fields (`AskUserQuestion`, one call each, in this order):**

1. **Package manager** — `header: "Pkg mgr"`, `multiSelect: false`,
   `options: [pnpm, npm, yarn, bun]` (each `label` the tool name; `description` one line).
   Pre-select the option matching `DETECTED_PM` when it appears in the list.
   The chosen label is the `Package manager` token and the prefix for the typecheck/test suggestions.
2. **Base branch** — `header: "Base branch"`, `multiSelect: false`. Build `options` from the repo's
   actual branches — run `git branch --format='%(refname:short)'` and offer `main`/`master`/`develop`
   when present (put the repo's current default first); the user can pick "Other" to type another.
3. **Lightweight threshold** — `header: "LW threshold"`, `multiSelect: false`,
   `options: [3 (default), 2, 5, 1]` (labels are the point values; mark `3` recommended). The choice
   is the `Lightweight threshold` value.
4. **Active agents** — `header: "Agents"`, `multiSelect: true`, `options:` the five domain agents
   below, each `label` the agent name and `description` its "select when…" row from the table. This
   is the ONLY multi-select picker; the result is the active-agent set.
5. **Review agent** — `header: "Review agent"`, `multiSelect: false`,
   `options: [claude-inline (Recommended), github-copilot, claude-superpowers]`. `claude-inline`
   (first/default) runs `/code-review` in-session and works on ANY repo with no external setup;
   pick `github-copilot` **only** when the repo has GitHub Copilot code review enabled and wants the
   bot to drive the loop; pick `claude-superpowers` for an in-session review that runs the superpowers
   `requesting-code-review` skill (a focused reviewer subagent) instead of native `/code-review` —
   same review→fix cycle, lower per-review token cost. The chosen label is the `Review agent` token.
6. **Review trigger** — `header: "Review trigger"`, `multiSelect: false`,
   `options: [on-update (Recommended), on-create, none]`. `on-update` (first/default) re-requests
   review on every push until the head is clean; `on-create` reviews once at PR creation;
   `none` raises the PR with no review gate (the loop is a no-op). The chosen label is the
   `Review mode` token.

**Free-text fields (plain questions, no picker):** Project name, Jira project key, Jira site (offer
the Step-2 host as the default), Typecheck command (suggest `DETECTED_TYPECHECK` as the default),
Test command (suggest `DETECTED_TEST` as the default), and each active agent's owned path(s). These
accept open string values, so a picker would be wrong.

**Active agents** are the workspace-owning **domain** agents — the ones that touch this repo's code.
Two tiers exist; only the domain tier is selectable:

- **Pipeline agents** — `product-manager`, `scrum-master`, `solutions-architect`, `tech-lead`,
  `principal-engineer`, `qa-engineer`. Always active, own no code, need **no** override file. Do
  **not** prompt for them.
- **Domain agents** — own paths and write code. Selectable below; each selected one gets a
  workspace→agent row and an override file.

**Selection guide — which domain agents does this repo need?** Present the options with this decision
aid (multi-select), so the user picks by what the repo actually contains, not by guessing:

| Agent | Select it when the repo has… | Typical owned paths |
| ----- | ---------------------------- | ------------------- |
| `platform-engineer` | a backend, API, serverless handlers, or infra/IaC | `services/`, `src/api/`, `functions/`, `infra/` |
| `web-engineer` | a web frontend (React/Vue/Svelte/etc.) | `apps/web/`, `src/web/`, `web/` |
| `mobile-engineer` | a mobile app (React Native / native iOS-Android) | `apps/mobile/`, `mobile/` |
| `database-administrator` | a relational schema you migrate (SQL, Prisma, Drizzle, TypeORM) | `db/`, `migrations/`, `prisma/` |
| `sync-engineer` | an **offline-sync** layer (sync rules, transaction builders, DLQ) | `sync/`, `src/sync/` |

Guidance to apply while prompting:

- **Pick only what exists today.** A backend-only service selects `platform-engineer` alone; a
  full-stack monorepo might select `platform-engineer` + `web-engineer` + `database-administrator`.
  Unsure → leave it out; standby roles can be activated later by hand (add a row + override).
- **`database-administrator`** is worth selecting separately from `platform-engineer` only when
  schema/migrations are a distinct concern with their own directory — it runs **before** the backend
  in the pipeline. A repo with no migrations does not need it.
- **`sync-engineer`** is niche — select it **only** for genuine offline-first sync, not for ordinary
  API calls. It runs after `database-administrator` and the backend.
- At least one domain agent should be selected; if the user selects none, confirm the repo really
  has no owned code (docs-only repo) before continuing.

For **each** selected agent, ask for its **owned path(s)** (suggest the typical paths above as
defaults, confirm against the repo) so the workspace→agent table and the override's Ownership line
carry real values.

## Step 3.5 — Suggest skills and refs based on detected stack

After configuration is collected, derive a list of candidate skills/refs from the detected stack
and present them for acceptance. This step happens **after** Step 3 so the package manager and
framework are confirmed.

### Skill suggestion mapping

Read `refs/skills-map.yml`. For each skill entry in the `skills` array, evaluate its `when`
conditions against the confirmed stack values:

- A `framework:` condition matches when `DETECTED_FRAMEWORK` contains that value.
- A `dep:` condition matches when that string appears as a key in the repo's `package.json`
  dependencies or devDependencies.
- A `package_manager_monorepo: pnpm` condition matches when `DETECTED_PM = pnpm` **and** the
  monorepo check in `monorepo_detection` resolves to true (count > 1).

If any condition for a skill matches, add it to the candidate list. De-duplicate the candidate
list — a skill appears at most once even if multiple conditions match it.

Each skill entry in `refs/skills-map.yml` carries a `description` field. Use that field verbatim
as the picker description for that skill — do not generate descriptions dynamically.

### Pre-select already-installed skills

If `.claude/project/skills.json` exists (detected in Step 2.5), read it and **mark every listed
skill as pre-selected** in the picker so teammates see already-installed skills as confirmed
defaults. New suggestions appear as additional options.

### Present the picker

```
AskUserQuestion(
  header: "Suggested skills",
  question: "Select the skills to install for this project. Already-installed skills are pre-selected.",
  multiSelect: true,
  options: [
    { label: "<skill-name>", description: "<description from refs/skills-map.yml>" },
    ... (one option per candidate, already-installed ones pre-selected)
  ]
)
```

The `description` for each option comes from the matching skill entry's `description` field in
`refs/skills-map.yml`. The "Other" escape (automatically appended by `AskUserQuestion`) lets the
user type a custom skill name not in the list. Custom entries receive `source: "custom"` in the
manifest.

The confirmed selection (accepted + any custom additions) is the **install list** used in Steps 4c
and 4d.

## Step 4 — Write the config files (real values, no placeholders)

Create the directories and write the files below. Every value must be the user's actual input or
the value detected and confirmed in the steps above — when you finish, **no placeholder tokens**
(`<...>`, `acme`, `TODO`) may remain in any generated file.

**4a. `.claude/.sdlc-plugin-root`** — the plugin-root marker the domain agents read to resolve
`${CLAUDE_PLUGIN_ROOT}`. Write the absolute SDLC plugin root (this command's own
`${CLAUDE_PLUGIN_ROOT}`) as a single line.

**4b. `.claude/project/project-context.md`** — fill the template in `refs/project-context-template.md`
from the collected and detected values. Replace every token slot with an actual value; the fill rules
are documented in that template file. Token slots to substitute:

| Token | Source |
| ----- | ------ |
| `<project name>` | user input (Step 3) |
| `<KEY>` | Jira project key (Step 3) |
| `<site>` | Jira site (Step 3) |
| `<base branch>` | base branch (Step 3) |
| `<pm>` | confirmed package manager (Step 3) |
| `<typecheck>` / `<test>` | confirmed commands (Step 3) |
| `<DETECTED_LANG>` | `DETECTED_LANG` (Step 2.5) |
| `<DETECTED_FRAMEWORK>` | `DETECTED_FRAMEWORK` (Step 2.5) |
| `<DETECTED_PM>` | `DETECTED_PM` (Step 2.5) |
| `<DETECTED_TEST>` | `DETECTED_TEST` (Step 2.5) |
| `<typecheck cmd>` / `<test cmd>` | confirmed commands (Step 3) |
| `<threshold>` | lightweight threshold (Step 3) |
| `<review-agent>` | Review agent picker (Step 3) — `claude-inline` default |
| `<review-mode>` | Review trigger picker (Step 3) — `on-update` default |
| workspace→agent rows | one row per active agent with its confirmed owned path(s) |

> **On the Merge-new-findings path** (Step 0): do **not** regenerate the file from scratch — preserve
> the existing `.claude/project/project-context.md` verbatim and only **inject the tokens/sections
> that were missing** (the backfill set collected in Step 0). A token already present keeps its stored
> value; a section the template defines but the file lacks is appended. This guarantees a re-init
> never clobbers hand-tuned values while still onboarding any newly introduced parameter.

**4c. `.claude/project/agents/<agent>.md`** — one file **per active agent only**. For each active
agent, fill the template in `refs/agent-override-template.md` using:

- The **agent domain mapping** table in `refs/agent-override-template.md` (which references skill
  domains from `refs/skills-map.yml` as the authoritative source) to filter the confirmed install
  list to skills relevant to this agent.
- The **run-order table** in `refs/agent-override-template.md` to populate the `runs after / before`
  line — list only agents that are active in this repo.
- The **per-agent filtering rules** in `refs/agent-override-template.md` for edge cases.

Fill the Ownership line with the real owned/forbidden paths and the run-order. Populate `## Tech rules`
and `## Local dev` from detected values (not placeholders). Every token slot in the template must be
replaced with an actual value — no `<...>` placeholders may remain.

Do not write override files for agents the user did not select.

**4d. `.claude/project/skills.json`** — write or merge the project skills manifest per
`refs/skills-manifest.md`. Build the array from the confirmed install list (Step 3.5):

- **First write** (file does not exist): create the file with `version: 1` and one entry per
  confirmed skill:
  ```json
  {
    "version": 1,
    "skills": [
      { "name": "<skill-name>", "source": "suggested", "addedBy": "init" },
      { "name": "<custom-skill>", "source": "custom", "addedBy": "init" }
    ]
  }
  ```
- **Merge write** (file already exists): read the existing array, union with the confirmed list
  (append skills not yet present, leave existing entries unchanged), and write the merged result.
  Never remove existing entries.
- If the confirmed install list is empty (user accepted no suggestions), write an empty `skills`
  array on first write; on merge write leave the existing entries untouched.

**4e. `.gitignore` — ensure `.tmp/` is excluded** — agent scratch files must never be committed.
Run the following to add the entry when it is absent:

```bash
# 4e — ensure .tmp/ is git-ignored (agent scratch must never be committed)
if [ ! -f .gitignore ] || ! grep -qxF '.tmp/' .gitignore; then
  printf '\n# agent scratch — SDLC plugin temp files (auto-cleaned, never commit)\n.tmp/\n' >> .gitignore
fi
```

This is idempotent — running it on a repo that already has `.tmp/` in `.gitignore` is a no-op.

## Step 5 — Post-init checklist (Jira fields you must configure)

Creating or modifying Jira custom fields is **out of scope** — but the pipeline needs them, so tell
the user exactly what to set up and how to verify. Print this checklist:

> Files written: `.claude/project/project-context.md`, agent overrides for `<active agents>`,
> `.claude/.sdlc-plugin-root`, and `.claude/project/skills.json`.
>
> **Configure these Jira custom fields on project `<KEY>` (the plugin reads but never creates them):**
>
> 1. **Story point estimate** (number) — the triage/route input. Verify it is on the story screen:
>    `acli jira workitem view <KEY>-<n> --fields 'Story point estimate' --json`
> 2. **AI Workflow** (single-select) with options `Full Auto`, `Auto`, `Assisted` — controls
>    auto-merge vs human-merge. Verify a value reads back:
>    `acli jira workitem search --jql 'project = <KEY> AND "AI Workflow" is not EMPTY' --fields key`
>
> Once both fields exist, the project is ready: run `/auto <KEY>-<n>` (or `/refine-feature` to start
> a new idea).
>
> **Next, to teach an agent your stack:** the scaffolded overrides
> (`.claude/project/agents/<agent>.md`) already list any skills confirmed during `/init`. To add more,
> write a skill at `.claude/skills/<name>/SKILL.md` (an ORM convention, an API-routing pattern, a
> deploy recipe…), list its name in the relevant override, and add it to `.claude/project/skills.json`
> manually — or re-run `/init` to go through the suggestion flow again (existing entries are
> preserved). To **activate a standby role later** that you skipped here (e.g. `mobile-engineer`),
> add its row to the workspace→agent table and create its override. Full walkthrough: `EXTENDING.md`.

## Final action — release the session

After everything above is complete (success, or a terminal STOP surfaced to the user), run this as
your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for. Outside the worker
(`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.
