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
       { label: "Refresh skills", description: "Re-fetch source- and plugin-backed skills to their latest upstream; config and hand-authored/stub skills are left untouched." },
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
     4. **Docs opt-in check.** The docs opt-in is **not** a `refs/project-context-template.md`
        token, so step 2's template-diff loop cannot surface it — check for it explicitly: if
        `.claude/project/docs-manifest.md` is **absent**, present the docs opt-in
        `AskUserQuestion` now (the identical prompt defined in Step 3's "Docs opt-in" section
        below). Accepting it here satisfies Step 4g's gate for this run, exactly as accepting it
        during a fresh Step 3 pass would. If the manifest already **exists**, skip this prompt
        entirely — Step 4g's existing-manifest merge guard runs regardless of any opt-in answer
        once a manifest exists (see Step 4g and the Docs opt-in section's Re-init semantics).
     5. Jump to Step 4b (write the merged project-context), Step 4d (merge skills.json), Step 4e
        (ensure .tmp/ is gitignored), Step 4g (merge `.claude/project/docs-manifest.md` against
        `refs/doc-types.md` — reached when step 4 above accepted the docs opt-in, or when the
        manifest already existed; runs the same existing-manifest merge guard described there), and
        Step 5.

   - **Refresh skills** → re-fetch the **managed** skills to their latest upstream, then **STOP** —
     no prompts, no other config rewritten. A managed skill is one whose `refs/skills-map.yml` entry
     declares a `source` or `plugin`; scaffolded stubs and custom skills (no source) are user-owned and
     left untouched. First, read `.claude/project/skills.json` for the installed skill list. Then
     group the installed managed skills by their `refs/skills-map.yml` entry and **run Step 4f in
     refresh mode** (see Step 4f): a `source` skill is cleanly replaced via stage-then-swap (download
     the latest upstream into a temp dir, then swap it into `.claude/skills/<name>/` only on success
     — never delete before a fetch that may fail), cloning each shared source repo once; a `plugin`
     skill is updated via `claude plugin marketplace add` then
     `claude plugin update <plugin>@<marketplace> --scope project`; a sourceless skill is skipped.
     Finally, leave `project-context.md`, the agent overrides, `skills.json`, and `.tmp/` gitignore
     untouched, print a summary of which skills were refreshed (and which were skipped as
     user-owned), then run the Final action release — do **not** continue to Steps 1–5.
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

| Variable                 | Detected value                                                      |
| ------------------------ | ------------------------------------------------------------------- |
| `DETECTED_LANG`          | e.g. `TypeScript`                                                   |
| `DETECTED_FRAMEWORK`     | e.g. `Hono`                                                         |
| `DETECTED_PM`            | e.g. `pnpm`                                                         |
| `DETECTED_TEST`          | e.g. `pnpm test`                                                    |
| `DETECTED_TYPECHECK`     | e.g. `pnpm typecheck`                                               |
| `DETECTED_RUNTIME`       | e.g. `Node 20` (empty if no version declaration found)              |
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
suggestion (see _Prompt mechanics_ below). Collect:

| Value                 | Notes                                                                                                                                                                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Project name          | repo/display name, e.g. `acme-api`                                                                                                                                                                                                          |
| Jira project key      | uppercase, e.g. `ACME` (validate with `acli jira project view <KEY>`)                                                                                                                                                                       |
| Jira site             | the authenticated host from Step 2 (offer it as the default)                                                                                                                                                                                |
| Base branch           | the integration branch PRs target, e.g. `main` or `develop`                                                                                                                                                                                 |
| Package manager       | `npm` / `pnpm` / `yarn` / `bun` / other — **pre-select `DETECTED_PM`**                                                                                                                                                                      |
| Typecheck command     | the project's typecheck — **default: `DETECTED_TYPECHECK`** (blank if none)                                                                                                                                                                 |
| Test command          | the project's test runner — **default: `DETECTED_TEST`** (blank if none)                                                                                                                                                                    |
| Lightweight threshold | story points at/under which `/auto` skips spec+plan; default `3`                                                                                                                                                                            |
| Active agents         | the **domain** agents whose code lives in this repo (see below)                                                                                                                                                                             |
| Review agent          | who drives the `/loop` review-fix cycle — `claude-inline` (default), `github-copilot`, or `claude-superpowers`                                                                                                                              |
| Review trigger        | when the loop requests/waits for review — `on-update` (default) / `on-create` / `none`                                                                                                                                                      |
| Review gate           | OPTIONAL — comma-separated subset of `spec,plan,impl` controlling which phases trigger automated review; default (omitted) = all phases. Not an interactive picker — write the `Review gate` token only if the repo wants per-phase gating. |

### Prompt mechanics (mandatory — do not fall back to plain text for picker fields)

Every **finite-choice** field below MUST be asked with the `AskUserQuestion` tool (the native
selectable picker), with **exactly** the `header`, `question`, `multiSelect`, and `options` given.
`AskUserQuestion` always appends an "Other" escape, so options need not be exhaustive. The
free-text fields MUST be asked as plain questions (no picker — open values have no finite set).

> **Minimum-options invariant (applies to EVERY `AskUserQuestion` call — batched or one-at-a-time).**
>
> - **Rule:** never place a question with fewer than 2 `options` into an `AskUserQuestion` call.
> - **Why it bites the whole call:** `AskUserQuestion` rejects the **entire call** — every question in
>   it, including the static ones — if _any single_ question has <2 options
>   (`too_small: expected array to have >=2 items`). One runtime field that computes to a single option
>   fails the whole prompt, even the static fields batched alongside it.
> - **What to do:** before issuing any call, compute each question's `options` and **exclude** any that
>   resolves to <2. Ask the excluded field **without a picker** instead — free-text pre-filled with the
>   single candidate as the default, or a yes/no confirm where a binary install/skip fits better (the
>   per-field guards below pick the right shape per field); skip the field entirely when no candidate
>   exists.
> - **Scope:** holds whether you ask one question per call (the documented default below) **or** batch
>   several. Only **Base branch** and **Suggested skills** are runtime-computed; every other picker has
>   a fixed ≥2 static list and is always safe.

**Picker fields (`AskUserQuestion`, one call each, in this order):**

1. **Package manager** — `header: "Pkg mgr"`, `multiSelect: false`,
   `options: [pnpm, npm, yarn, bun]` (each `label` the tool name; `description` one line).
   Pre-select the option matching `DETECTED_PM` when it appears in the list.
   The chosen label is the `Package manager` token and the prefix for the typecheck/test suggestions.
2. **Base branch** — `header: "Base branch"`, `multiSelect: false`. Build `options` from the repo's
   actual branches — run `git branch --format='%(refname:short)'` and offer `main`/`master`/`develop`
   when present (put the repo's current default first); the user can pick "Other" to type another.
   **Guard the option count:** `AskUserQuestion` requires **at least 2 options**, so a repo with a
   single base-branch candidate (e.g. a fresh repo with only `main`) would crash the picker. Only
   call `AskUserQuestion` when **2 or more** candidates exist. When **fewer than 2 candidates** are
   found, skip the picker and instead ask a **plain free-text question pre-filled with the single
   candidate (if any) as the default** — this avoids the crash and preserves the user's ability to
   type a base branch not present locally (e.g. a not-yet-created `develop` on a `main`-only repo).
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
Three categories exist; only the domain tier is a multi-select pick:

- **Pipeline agents** — `product-manager`, `scrum-master`, `solutions-architect`, `tech-lead`,
  `principal-engineer`, `qa-engineer`. Always active, own no code, need **no** override file. Do
  **not** prompt for them.
- **Domain agents** — own paths and write code. Selectable below; each selected one gets a
  workspace→agent row and an override file.
- **`ai-enablement-engineer`** — a special case: gated by its own single opt-in confirm (see
  **AI-context opt-in** below), not by this multi-select. It owns the repo's AI-configuration
  surface plus `plugins/`/`skills/` once opted in, and is never offered as an option in the
  multi-select picker below.

**Selection guide — which domain agents does this repo need?** Present the options with this decision
aid (multi-select), so the user picks by what the repo actually contains, not by guessing:

| Agent                    | Select it when the repo has…                                      | Typical owned paths                             |
| ------------------------ | ----------------------------------------------------------------- | ----------------------------------------------- |
| `platform-engineer`      | a backend, API, serverless handlers, or infra/IaC                 | `services/`, `src/api/`, `functions/`, `infra/` |
| `web-engineer`           | a web frontend (React/Vue/Svelte/etc.)                            | `apps/web/`, `src/web/`, `web/`                 |
| `mobile-engineer`        | a mobile app (React Native / native iOS-Android)                  | `apps/mobile/`, `mobile/`                       |
| `database-administrator` | a relational schema you migrate (SQL, Prisma, Drizzle, TypeORM)   | `db/`, `migrations/`, `prisma/`                 |
| `sync-engineer`          | an **offline-sync** layer (sync rules, transaction builders, DLQ) | `sync/`, `src/sync/`                            |

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

**AI-config paths are never `platform-engineer`'s default.** `platform-engineer`'s typical owned
paths above intentionally exclude AI-config paths (`plugins/`, `skills/`, `.claude/**`,
`CLAUDE.md`/`AGENT(S).md`, etc.) — those belong to `ai-enablement-engineer`, gated by its own
opt-in immediately below, not to any backend/infra selection here. If a user free-types
`plugins/` or `skills/` as a `platform-engineer` owned path, confirm they instead mean the
AI-context opt-in below and steer them there instead of recording the path under
`platform-engineer`.

### AI-context opt-in (`ai-enablement-engineer`)

`ai-enablement-engineer` is gated by a single opt-in confirm, separate from the domain-agent
multi-select above — it is Active only when this repo opts in, never by default. Ask:

```
AskUserQuestion(
  header: "AI-config mgmt",
  question: "Opt this repo into AI-config management? ai-enablement-engineer would own plugins/, skills/, and the repo's AI-config surface (CLAUDE.md, .claude/**, AGENT(S).md, etc.), and expose /sdlc:analyze for drift/gap/memory-conflict scanning.",
  multiSelect: false,
  options: [
    { label: "Opt in", description: "Grant ai-enablement-engineer ownership of plugins/, skills/, and the AI-config surface; scaffold its override; mark it Active." },
    { label: "Skip", description: "Leave ai-enablement-engineer inactive — no rows written, no override created. Re-run /init later to opt in." }
  ]
)
```

- **Opt in** → carry two effects into Step 4:

  (a) **Workspace→agent rows** — for each of `plugins/`, `skills/`: write a `<dir>/` →
  `ai-enablement-engineer` row to the Step 4b table **only if that directory exists in this
  repo**. Writing a row for a directory that doesn't exist yet is guaranteed false drift on the
  very first `/sdlc:analyze` scan (the "Workspace→agent table vs disk" check in
  `analyze-protocol.md#drift--gap-table` flags exactly this: "Table lists a path that no longer
  exists"). At least one row must land to mark the agent **Active** — row presence is the sole
  Active signal, no separate flag exists (`analyze-protocol.md#ownership-resolution-rules`):
  `plugins/` exists in essentially every consumer repo (this plugin's own install lives there),
  so in practice it is almost always the row that survives. If genuinely **neither** `plugins/`
  nor `skills/` exists yet, still scaffold the override (below) and write one row for the
  AI-config surface root (`.claude/` — a judgment call, note the rationale in the row) so the
  Active signal holds regardless. When a skipped directory appears later, add its row on the
  next `/init` "Merge new findings" pass or by hand — the agent's write-scope already covers it
  via the config-driven AI-config surface baseline even before a table row names it explicitly.

  **Migration (the sole documented exception to Step 0's "never touch values already
  present"):** if `plugins/` or `skills/` already has a workspace→agent row under a
  **different** owner (e.g. a legacy `platform-engineer` row predating this agent), the opt-in
  confirmation **reassigns** that row to `ai-enablement-engineer` rather than leaving both a
  stale row and a new one — one path, one owner is the ownership model's core invariant. This
  reassignment fires only when the user explicitly confirms this AI-context opt-in prompt; it
  never happens silently on a plain re-init "Merge new findings" pass with no opt-in involved.

  (b) scaffold `.claude/project/agents/ai-enablement-engineer.md` in Step 4c using
  the **fixed** override shape below (its skill list and owned paths are fixed by the agent
  definition, not derived from the Step 3.5 stack-suggestion flow the other overrides use):

  ```markdown
  # AI Workflow Manager — <project name> bindings

  ## Skills (plugin-bundled — invoke via the Skill tool)

  1. skill-creator
  2. find-skills
  3. conventional-commit

  ## Directory guides (read before coding)

  # No directory guides yet — add CLAUDE.md files to owned paths.

  ## Ownership

  - owns: plugins/, skills/, .claude/, CLAUDE.md, AGENT.md/AGENTS.md and the AI-config surface (baseline globs ship in the agent definition; this override may add more)
  - never: .claude/project/project-context.md, `.claude/.*-plugin-root` pointers, other agents' memory files
  - runs after: — · before: —

  ## Tech rules

  - Markdown/Shell; kebab-case file naming; any shell script touched must pass `bash tools/portability-lint.sh` if the repo has that gate.

  ## Local dev (tokens from project-context Tooling)

  - Typecheck: `<confirmed typecheck cmd, or "none configured">` · Test: `<confirmed test cmd, or "none configured">`
  - Never run cloud deploys — those are manual ops actions outside agent scope.
  ```

  Substitute `<project name>` and the typecheck/test tokens from the values already collected
  above (Step 3) — no `<...>` placeholder may remain.

- **Skip** → add no workspace→agent row for `ai-enablement-engineer` and scaffold no override.
  The agent stays inactive with no effect on the repo — its definition is repo-agnostic, so
  there is nothing to undo later; opting in is always available on a future `/init` run.
- **Re-init semantics** — this prompt is a normal Step 3 field, so it participates in the Step 0
  "Merge new findings" schema-backfill exactly like any other: a repo that has not opted in yet
  (no `ai-enablement-engineer` rows present) is prompted once when merging; a repo that already
  opted in (its rows already present) is never re-prompted — the existing rows and override are
  kept verbatim, matching Step 0's "never touch values already present" rule.

### Docs opt-in (`/sdlc:docs` generation)

Presented **after stack detection completes** (Step 2.5), alongside the AI-context opt-in above.
This is an **independent** confirm — accepting or declining it has no bearing on the AI-context
opt-in, and either may be accepted without the other. Ask:

```
AskUserQuestion(
  header: "Docs generation",
  question: "Scaffold a docs-manifest so /sdlc:docs can generate public documentation for this repo?",
  multiSelect: false,
  options: [
    { label: "Opt in", description: "Write .claude/project/docs-manifest.md pre-filled with doc-type rows relevant to the detected stack. Activates docs generation." },
    { label: "Skip",   description: "Write no manifest. All docs features stay a silent no-op. Re-run /init later to opt in." }
  ]
)
```

- **Opt in** → Step 4g (below) writes or merges `.claude/project/docs-manifest.md`.
- **Skip** → Step 4g writes nothing — but **only when no manifest exists yet**. Once
  `.claude/project/docs-manifest.md` exists (from any prior run), an existing manifest **always**
  triggers Step 4g's merge behaviour regardless of this run's opt-in answer: Skip means "don't
  create one," never "stop merging an existing one" — the merge behaviour only _offers_ new rows
  (each confirmed individually via the per-row merge/confirm flow), so it never writes anything
  this run's answer didn't separately authorize.
- **Re-init semantics** — this opt-in is **not** a `refs/project-context-template.md` token, so
  the Step 0 "Merge new findings" template-diff loop never surfaces it; a dedicated check does
  instead (see Step 0's merge flow, step 4). Decline is **per-run and deliberately unpersisted** —
  there is no record of an opt-in decline (unlike the per-row `<!-- declined: … -->` record inside
  an _existing_ manifest, which Step 4g does honor). A manifest-less repo is therefore re-prompted
  on **every** (re-)init or merge run for as long as the manifest stays absent. Once a manifest
  exists, this prompt is no longer asked, and Step 4g's existing-manifest merge guard governs from
  then on regardless of this run's answer (see Step 4g below).

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

**Guard the option count (same ≥2 rule as the base-branch picker):** `AskUserQuestion` requires
**at least 2 options**, so the dynamically-built candidate skill list can crash it when fewer than 2
skills match. Only render the picker when **2 or more** candidates exist. When exactly **one**
candidate matches, skip the picker and ask a single plain yes/no confirm to install it; when **none**
match, skip the skills step entirely (render no picker).

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

| Token                            | Source                                                                                                                                                                                                |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<project name>`                 | user input (Step 3)                                                                                                                                                                                   |
| `<KEY>`                          | Jira project key (Step 3)                                                                                                                                                                             |
| `<site>`                         | Jira site (Step 3)                                                                                                                                                                                    |
| `<base branch>`                  | base branch (Step 3)                                                                                                                                                                                  |
| `<pm>`                           | confirmed package manager (Step 3)                                                                                                                                                                    |
| `<typecheck>` / `<test>`         | confirmed commands (Step 3)                                                                                                                                                                           |
| `<DETECTED_LANG>`                | `DETECTED_LANG` (Step 2.5)                                                                                                                                                                            |
| `<DETECTED_FRAMEWORK>`           | `DETECTED_FRAMEWORK` (Step 2.5)                                                                                                                                                                       |
| `<DETECTED_PM>`                  | `DETECTED_PM` (Step 2.5)                                                                                                                                                                              |
| `<DETECTED_TEST>`                | `DETECTED_TEST` (Step 2.5)                                                                                                                                                                            |
| `<typecheck cmd>` / `<test cmd>` | confirmed commands (Step 3)                                                                                                                                                                           |
| `<threshold>`                    | lightweight threshold (Step 3)                                                                                                                                                                        |
| `<review-agent>`                 | Review agent picker (Step 3) — `claude-inline` default                                                                                                                                                |
| `<review-mode>`                  | Review trigger picker (Step 3) — `on-update` default                                                                                                                                                  |
| workspace→agent rows             | one row per active agent with its confirmed owned path(s) — including `plugins/` → `ai-enablement-engineer` and `skills/` → `ai-enablement-engineer` when the AI-context opt-in (Step 3) was accepted |

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

**`ai-enablement-engineer` is scaffolded separately, not through this stack-driven flow.** Only
write `.claude/project/agents/ai-enablement-engineer.md` when the AI-context opt-in (Step 3) was
accepted, and use the **fixed** override content given there — it does not use the agent domain
mapping / run-order tables above, since its skill list (`skill-creator`, `find-skills`,
`conventional-commit`) and owned paths are fixed by the agent definition, not derived from the
Step 3.5 stack suggestions.

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

**4f. Install each confirmed skill into project scope.** Steps 4c and 4d only _record_ the confirmed
skills (in the agent overrides and `skills.json`); neither makes a skill discoverable. A skill is only
invocable when its content is actually installed on disk. Without this step, `/init` leaves the
selected skills tracked but absent and unavailable to the domain agents (the reported defect). Resolve
each skill in the confirmed install list (Step 3.5) by the **first** matching path below — `source`
is preferred because it installs the skill's real content from an exact location:

- **Direct source (preferred)** — the skill's `refs/skills-map.yml` entry declares a `source` (the
  exact location of the skill content: a git repository ref, or a raw URL to a single `SKILL.md`),
  optionally with `path` (subdirectory of the skill within that repo) and `ref` (branch/tag/SHA,
  default the repo's default branch). Download that exact content into `.claude/skills/<name>/` so the
  installed skill is the **real** skill, not a stub. **De-duplicate by `source` + `ref`:** when several
  confirmed skills share one `source` URL **and** the same `ref`, clone that repo **once** and copy each
  skill's `path` out of the single clone. Skills from the same repo pinned to **different** `ref`s need
  a separate clone each (one clone can only be checked out at a single ref) — group by the (`source`,
  `ref`) pair, not by `source` alone.

  ```bash
  # git source — partial + sparse clone of ONE repo (shared across skills from the same source):
  # --filter=blob:none + sparse-checkout transfer only the needed path(s), not the whole tree.
  tmp="$(mktemp -d)"
  git clone --filter=blob:none --sparse "<source>" "$tmp"
  git -C "$tmp" sparse-checkout set "<path>"        # add every needed <path> for this repo
  # `ref` may be a branch, tag, OR commit SHA — check it out explicitly. Do NOT use
  # `git clone --branch`, which only resolves branch/tag names and rejects a SHA. Skip when unset.
  [ -n "<ref>" ] && git -C "$tmp" checkout --quiet "<ref>"
  mkdir -p ".claude/skills/<name>"
  cp -R "$tmp/<path>/." ".claude/skills/<name>/"     # repeat the copy per skill from this repo
  rm -rf "$tmp"
  ```

  If `source` is a raw URL to a single file, fetch it directly instead:

  ```bash
  mkdir -p ".claude/skills/<name>"
  curl -fsSL "<source>" -o ".claude/skills/<name>/SKILL.md"
  ```

  **The directory name is the skill's identity** — Claude Code resolves a project skill by its
  directory (`.claude/skills/<name>/`), not by the `SKILL.md` frontmatter `name` (which is a cosmetic
  display label, optional, and defaults to the directory name). The copy above already lands the
  content in `.claude/skills/<name>/`, so the installed skill is discovered and invoked as `<name>` and
  matches `skills.json` / the agent override — **even when the upstream uses a different directory or
  frontmatter `name`** (e.g. `composition-patterns`, or a colon form like `react:components`). Do
  **not** rewrite the downloaded content to "normalize" the name: leaving it byte-identical to upstream
  keeps future updates (re-fetch / diff) clean. If a fetch fails (network, bad ref, missing path), do
  **not** silently fall through to a stub — surface the failure for that skill so the gap is visible,
  and continue with the remaining skills.

- **Marketplace plugin** — the entry declares `plugin` (`<plugin>@<marketplace>`) + `marketplace`
  instead of a `source`. **Claude Code has no per-skill install — skills ship inside plugins** — so
  install the **providing plugin** at project scope (de-duplicate: install each distinct plugin once
  even when several confirmed skills come from it):

  ```bash
  # idempotent: register the marketplace, then install the providing plugin at project scope
  claude plugin marketplace add <marketplace-source>
  claude plugin install <plugin>@<marketplace> --scope project
  ```

  Project scope records the plugin in `.claude/settings.json` `enabledPlugins` (committed), so every
  teammate gets the skill on checkout. Do **not** write any file under `.claude/skills/` for these —
  the plugin owns the skill content.

- **No source declared** (custom skills, and any entry with neither `source` nor `plugin`) — scaffold
  a local starter skill at `.claude/skills/<name>/SKILL.md`, substituting the skill's real `name` and
  `description` (from `refs/skills-map.yml`, or the user's stated purpose for a custom skill):

  ```markdown
  ---
  name: <name>
  description: <description>
  ---

  # <name>

  Project-scoped skill installed by `/init` for this repository's stack. It is discoverable
  immediately via the Skill tool. Extend this body with the conventions, patterns, and examples this
  project expects when the skill applies — the frontmatter `description` drives when agents reach for it.
  ```

Rules:

- **Idempotent — skip-if-exists / already-installed.** If `.claude/skills/<name>/SKILL.md` already
  exists, or the providing plugin is already installed, leave it **untouched** — never re-download,
  re-install, or clobber a hand-authored skill. `git clone` into a fresh temp dir, `claude plugin
marketplace add` / `install`, and the stub write are all otherwise safe to re-run.
- **Refresh mode** (entered from Step 0's "Refresh skills"): the skip-if-exists guard is lifted **only
  for managed skills** — a skill whose `refs/skills-map.yml` entry declares a `source` or `plugin`. For
  those, re-fetch to pick up upstream changes:
  - A `source` skill is **cleanly replaced**, not merged — but **stage-then-swap**, never delete first.
    `cp -R` alone leaves behind files upstream renamed/deleted, yet `rm -rf` _before_ a re-fetch that
    might fail (transient network, renamed `ref`/`path`, auth) would destroy a working skill. Stage the
    new content **on the same filesystem** as the destination (so the swap is a real rename, not a
    cross-device copy that can fail mid-write), and swap **only after the staged dir is confirmed
    populated**:
    ```bash
    mkdir -p ".claude/skills"
    stage="$(mktemp -d -p .claude/skills)"            # same filesystem as the destination
    # …run the Direct-source download (above) but copy into "$stage/<name>".
    # Guard the swap on a successfully populated staging dir — only then remove + rename:
    if [ -e "$stage/<name>/SKILL.md" ]; then
      rm -rf ".claude/skills/<name>"
      mv "$stage/<name>" ".claude/skills/<name>"      # same-fs rename = atomic
    else
      echo "refresh: download failed for <name>; keeping existing install" >&2
    fi
    rm -rf "$stage"
    ```
    **De-duplicate by repo + ref** (as on the install path): when several refreshed skills share one
    `source` repo _and_ the same `ref`, clone it once and stage each skill's `path` from that single
    clone. Skills from the same repo pinned to **different** `ref`s need separate clones (one per ref)
    — a single clone can only be checked out at one ref.
  - A `plugin` skill is refreshed with `claude plugin update`. As on the install path, **register the
    marketplace first** (it may be absent on a fresh checkout where only committed settings record the
    plugin), then update:
    ```bash
    claude plugin marketplace add <marketplace-source>   # idempotent; needed if not yet registered
    claude plugin update <plugin>@<marketplace> --scope project
    ```
  - A **sourceless** skill (scaffolded stub / custom) is user-owned and is **always skipped** in
    refresh mode — never overwritten.
- **The directory name `<name>` is the identifier across the sync trio** — it is what Claude Code
  resolves the skill by, and what `skills.json` / the agent override record. The `SKILL.md` frontmatter
  `name` is a cosmetic display label (it need not match), so downloaded content is left byte-identical
  to upstream; scaffolded stubs are written with `<name>` for tidiness.
- A scaffolded stub body is a starter, not a placeholder token: once `<name>`/`<description>` are
  substituted, no `<...>` slot remains, so it satisfies the Step 4 no-placeholder rule. Teammates
  fill in the body later (or replace the stub with a richer skill).
- If the confirmed install list is empty (no suggestions accepted, no custom skills), this step is a
  no-op — install nothing, write no files.

**4g. `.claude/project/docs-manifest.md`** — executed whenever **either** the docs opt-in was
accepted this run (Step 3, or Step 0's merge-flow docs-opt-in check) **or**
`.claude/project/docs-manifest.md` already exists from a prior run — an existing manifest always
reaches this step regardless of this run's opt-in answer (see the Docs opt-in section's Re-init
semantics). Declining the opt-in **with no pre-existing manifest** writes nothing (no file, no
partial content).

Step 4g MUST **first detect whether the manifest already exists** — this existing-manifest merge
guard applies on **every** path that reaches Step 4g, including a full "re-run setup" pass, not
only the Step 0 "Merge new findings" path:

```bash
[ -f ".claude/project/docs-manifest.md" ] && echo "MANIFEST_EXISTS=yes" || echo "MANIFEST_EXISTS=no"
```

- **If absent** — fill `refs/docs-manifest-template.md` with the subset of `refs/doc-types.md`
  rows whose `applies-when` matches the detected stack (v1: every row — all 15 mandatory rows use
  `applies-when = always`). Write each row's `type`, `enabled = true`, and the registry row's
  default `target-path` token, using the header comment and row-table shape defined in
  `refs/docs-manifest-template.md`. Never leave a `<...>` placeholder in the written file.

  After writing the row table + header comment, and **only if the founder accepted the docs opt-in
  this run**, **offer** (do not autonomously write) an optional additional-keys prompt:

  > Does this repo carry commits under more than one Jira project key (e.g. after a Jira rename or a
  > repo merge)? List additional prefixes, or leave blank to skip.
  - **Founder supplies keys** → **validate** each is key-shaped: it must match `^[A-Z][A-Z0-9]*$` —
    a bare project prefix, **no** `-<number>`, **no** angle-bracket placeholder such as `<PREFIX>`.
    Re-prompt on any token that fails. Then write a real `## Additional Jira project keys` section
    (below the table, and below "Voice & format" if present) containing **exactly those validated
    founder-supplied keys** as a comma-separated list — **no stub, no example, no placeholder**
    (honouring the template's no-`<...>` Fill rule). The header written this run already documents
    the section (AC2), so header and body are consistent by construction.
  - **Founder leaves blank** → **write nothing** for the section. It stays absent and founder-owned.

  This offer is the **fresh-write path only**. It never runs on the merge path (below), and it never
  writes the section without an explicit founder-supplied value.

- **If present** — never regenerate from defaults. This is the merge behaviour (reuses the Step 0
  "Merge new findings" mechanic and the Step 4d `skills.json` merge pattern; the merge source for
  docs rows is `refs/doc-types.md`, **not** any `refs/project-context-template.md` token set):
  1. Read the existing manifest's rows and its `<!-- declined: <type>[, <type>...] -->` comment
     line(s), if any.
  2. For every `refs/doc-types.md` row whose `applies-when` matches the detected stack **and**
     is **absent** from the manifest **and** is **not** already recorded as declined: **offer to
     append it**, one row at a time, via the same merge/confirm mechanic Step 0's "Merge new
     findings" and Step 4d's `skills.json` merge use. The founder confirms or declines per row.
  3. **Accepted** → append the row (`type`, `enabled = true`, the registry default
     `target-path`) to the table, preserving the position of every existing row.
  4. **Declined** → record it in a `<!-- declined: <type>[, <type>...] -->` comment line (append
     the type to an existing line, or add a new one) so subsequent re-runs read it and **skip
     re-offering** that type.
  5. **Rows already present are kept verbatim** — their edited `target-path`, their `enabled`
     value, and their table position are all preserved. Never remove or rewrite an existing
     manifest row.

Error / no-op branches:

| Scenario                                                                   | Behaviour                                                                                                                                             |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Docs opt-in declined (or never asked) and no manifest exists yet           | Write no manifest file. No error — re-prompted on the next (re-)init or merge run per the Docs opt-in section's Re-init semantics.                    |
| Docs opt-in declined (or not asked) this run but a manifest already exists | Step 4g still runs its existing-manifest merge behaviour (see the rows below) — an existing manifest is never gated on this run's opt-in answer.      |
| Manifest absent, opt-in accepted                                           | Fill from `refs/docs-manifest-template.md` per the "If absent" branch above.                                                                          |
| Manifest present, new non-declined matching rows exist                     | Offer to append them per-row (merge/confirm); keep existing rows verbatim; record any decline in the `<!-- declined: … -->` comment. Never overwrite. |
| Manifest present, no new (non-declined) rows                               | No-op on the manifest; print it as unchanged.                                                                                                         |
| `refs/doc-types.md` unreadable or malformed at scaffold time               | Surface the failure and **skip** the manifest write — never write a half-filled manifest.                                                             |

## Step 5 — Post-init checklist (Jira fields you must configure)

Creating or modifying Jira custom fields is **out of scope** — but the pipeline needs them, so tell
the user exactly what to set up and how to verify. Print this checklist:

> Files written: `.claude/project/project-context.md`, agent overrides for `<active agents>`
> (plus `ai-enablement-engineer`'s override if the AI-context opt-in was accepted),
> `.claude/.sdlc-plugin-root`, and `.claude/project/skills.json`
> (plus `.claude/project/docs-manifest.md` if the docs opt-in was accepted). Confirmed skills are
> installed (Step 4f): from their declared `source` into `.claude/skills/<name>/`, or via
> `claude plugin install … --scope project` for plugin-backed ones, the rest as
> `.claude/skills/<name>/SKILL.md` scaffolds.
>
> **Configure these Jira custom fields on project `<KEY>` (the plugin reads but never creates them):**
>
> 1. **Story point estimate** (number) — the triage/route input. Verify it is on the story screen:
>    `acli jira workitem view <KEY>-<n> --fields 'Story point estimate' --json`
> 2. **AI Workflow** (single-select) with options `Full Auto`, `Auto`, `Assisted` — controls
>    auto-merge vs human-merge. Verify a value reads back:
>    `acli jira workitem search --jql 'project = <KEY> AND "AI Workflow" is not EMPTY' --fields key`
>    _No admin access to create custom fields?_ Issues can opt in with an
>    `AI-Workflow:<full-auto|auto|assisted>` label instead — the field, when set, always wins; with
>    multiple such labels the most conservative mode applies (`assisted` > `auto` > `full-auto`).
>
> Once **Story point estimate** exists (always required) and an AI Workflow mode source is in
> place — the field, or the label convention on projects that cannot create it — the project is
> ready: run `/auto <KEY>-<n>` (or `/refine-feature` to start a new idea).
>
> **Next, to teach an agent your stack:** the scaffolded overrides
> (`.claude/project/agents/<agent>.md`) already list any skills confirmed during `/init`. Skills with
> a declared `source` were downloaded into `.claude/skills/<name>/`, plugin-backed ones were installed
> as plugins, and project-convention skills got a starter `.claude/skills/<name>/SKILL.md` — fill in
> those bodies with your project's conventions. To add a
> skill not suggested, write `.claude/skills/<name>/SKILL.md` (an ORM convention, an API-routing
> pattern, a deploy recipe…), list its name in the relevant override, and add it to
> `.claude/project/skills.json` — or re-run `/init` to go through the suggestion flow again (existing
> skill files, installed plugins, and manifest entries are preserved). To **activate a standby role later** that you skipped here (e.g. `mobile-engineer`),
> add its row to the workspace→agent table and create its override. Full walkthrough: `EXTENDING.md`.

## Final action — release the session

After everything above is complete (success, or a terminal STOP surfaced to the user), run this as
your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for. Outside the worker
(`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.
