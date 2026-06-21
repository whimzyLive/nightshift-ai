---
description: One-command onboarding for a new repo — interactively scaffolds .claude/project/project-context.md, the active agents' override files, and the plugin-root marker, after gating on the gh/acli prerequisites and walking you through acli authentication. Ends with a post-init checklist of the Jira custom fields you must configure by hand.
---

Onboard **this repository** to nightshift SDLC. Walk the user through prerequisites, authentication,
and configuration, then write every file the plugin needs to run here. `$ARGUMENTS` is ignored —
`/init` is always interactive.

This command runs **in order**: a missing prerequisite must never leave half-written config, and
authentication is verified **before** any file is generated. Do the steps below top to bottom and
**STOP** at the first failure, surfacing an actionable message.

> **Idempotency is out of scope.** This command assumes a fresh project. If
> `.claude/project/project-context.md` already exists, tell the user it is already initialised and
> STOP — do not overwrite it. (Re-init / migration is a separate story.)

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

- **Authenticated** → continue to Step 3.
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

## Step 3 — Collect configuration (one value at a time)

Prompt the user for each value **individually** (use `AskUserQuestion` where there is a finite
choice; ask plainly otherwise). Do not batch them into one wall of questions. Collect:

| Value | Notes |
| ----- | ----- |
| Project name | repo/display name, e.g. `acme-api` |
| Jira project key | uppercase, e.g. `ACME` (validate with `acli jira project view <KEY>`) |
| Jira site | the authenticated host from Step 2 (offer it as the default) |
| Base branch | the integration branch PRs target, e.g. `main` or `develop` |
| Package manager | `npm` / `pnpm` / `yarn` / `bun` / other |
| Typecheck command | the project's typecheck, e.g. `pnpm typecheck` (blank if none) |
| Test command | the project's test runner, e.g. `pnpm test` (blank if none) |
| Lightweight threshold | story points at/under which `/auto` skips spec+plan; default `3` |
| Active agents | the **domain** agents whose code lives in this repo (see below) |

**Active agents** are the workspace-owning domain agents. Offer this set and let the user pick the
ones that apply (multi-select):

- `platform-engineer` — backend / serverless / infra
- `web-engineer` — web frontend
- `mobile-engineer` — mobile app
- `database-administrator` — relational schema + migrations
- `sync-engineer` — offline-sync layer

The pipeline agents (`product-manager`, `scrum-master`, `solutions-architect`, `tech-lead`,
`principal-engineer`, `qa-engineer`) are always active and need **no** override file — do not prompt
for them.

For **each** active agent, also ask for its **owned path(s)** (e.g. `services/api/` for
`platform-engineer`) so the workspace→agent table can be filled with real values.

## Step 4 — Write the config files (real values, no placeholders)

Create the directories and write the files below. Every value must be the user's actual input — when
you finish, **no placeholder tokens** (`<...>`, `acme`, `TODO`) may remain in any generated file.

**4a. `.claude/.sdlc-plugin-root`** — the plugin-root marker the domain agents read to resolve
`${CLAUDE_PLUGIN_ROOT}`. Write the absolute SDLC plugin root (this command's own
`${CLAUDE_PLUGIN_ROOT}`) as a single line.

**4b. `.claude/project/project-context.md`** — from the collected values:

```markdown
# Project Context

| Token                | Value                  |
| -------------------- | ---------------------- |
| Project name         | <project name>         |
| Jira project key     | <KEY>                  |
| Jira site            | <site>                 |
| Base branch          | <base branch>          |
| Package manager      | <pm>                   |
| Typecheck / Test     | <typecheck> / <test>   |

## Workspace → agent
| Path            | Owner             |
| --------------- | ----------------- |
<one row per active agent: its owned path → the agent>

## Tooling
| Typecheck | `<typecheck cmd>` |
| Test      | `<test cmd>`      |

## Triage

| Token | Value |
| ----- | ----- |
| Lightweight threshold (story points, inclusive) | `<threshold>` |
```

Omit the Typecheck/Test rows the user left blank rather than writing an empty backtick pair.

**4c. `.claude/project/agents/<agent>.md`** — one file **per active agent only**, from the override
contract in `EXTENDING.md`. Fill the Ownership line with the real owned/forbidden paths and the
run-order; leave the project-skill list as a commented starter the user fills in later:

```markdown
# <Agent display name> — <project name> bindings

## Project skills (invoke in order via the Skill tool)
# Add skills you write under .claude/skills/<name>/SKILL.md, then list them here.

## Directory guides (read before coding)
# - <owned path>/CLAUDE.md

## Ownership
- owns: <this agent's owned path(s)>
- never: <other agents' owned paths>
- runs after: <upstream agent or "—"> · before: <downstream agent or "—">

## Tech rules
# <Framework + runtime>, language strictness, file-naming, "always/never" rules.

## Local dev (tokens from project-context Tooling)
- Typecheck: `<typecheck cmd>` · Test: `<test cmd>`
```

Do not write override files for agents the user did not select.

## Step 5 — Post-init checklist (Jira fields you must configure)

Creating or modifying Jira custom fields is **out of scope** — but the pipeline needs them, so tell
the user exactly what to set up and how to verify. Print this checklist:

> ✅ Files written: `.claude/project/project-context.md`, agent overrides for `<active agents>`, and
> `.claude/.sdlc-plugin-root`.
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

## Final action — release the session

After everything above is complete (success, or a terminal STOP surfaced to the user), run this as
your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for. Outside the worker
(`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.
