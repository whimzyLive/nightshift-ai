---
title: Jira and GitHub setup for sdlc
description: Wire a repo's sdlc plugin to Jira Cloud and GitHub so the pipeline can read stories and open PRs
source:
  - plugins/sdlc/commands/init.md
related-adrs: []
---

# Jira and GitHub setup for sdlc

Connect this repo's sdlc plugin to Jira Cloud and GitHub. When done, the pipeline can read stories from Jira and open PRs on GitHub. `/sdlc:init` gates on both integrations before it writes any config, so wire them first.

For what the pipeline does with these connections, see [docs/concepts/what-is-the-sdlc-plugin.md](../concepts/what-is-the-sdlc-plugin.md). For a first end-to-end run, see [docs/tutorials/getting-started-with-sdlc.md](../tutorials/getting-started-with-sdlc.md).

## Prerequisites

- Admin or contributor access to the target GitHub repo.
- A Jira Cloud account on the site whose project the repo tracks.
- A Jira API token. Create one at <https://id.atlassian.com/manage-profile/security/api-tokens>.
- Ability to configure Jira project custom fields (or a project admin who can). See [Jira custom fields](#jira-custom-fields).

`/sdlc:init` refuses to run until both `gh` and `acli` are installed and `acli` is authenticated. Install and authenticate both before running it.

## Install and authenticate the GitHub CLI

1. Install `gh`.
   - macOS: `brew install gh`
   - Debian/Ubuntu: follow <https://github.com/cli/cli/blob/trunk/docs/install_linux.md>
   - Other: <https://cli.github.com/>
2. Authenticate against the account that owns the repo:

   ```bash
   gh auth login
   ```

   Choose `GitHub.com`, `HTTPS`, and authenticate in the browser or with a token. Grant `repo` scope so the pipeline can open and comment on PRs.

## Install and authenticate the Atlassian CLI (acli)

The pipeline talks to Jira through `acli`, not the Atlassian MCP, to keep token cost low.

1. Install `acli`.
   - macOS: `brew tap atlassian/homebrew-acli && brew install acli`
   - Linux / other: <https://developer.atlassian.com/cloud/acli/guides/install-acli/>
2. Log in with your site host, email, and API token:

   ```bash
   acli jira auth login --site "your-org.atlassian.net" --email "you@your-org.com" --token "<api-token>"
   ```

   Use the bare host for `--site` (no `https://`, no trailing path). This is the same login walkthrough `/sdlc:init` runs at Step 2 when it finds you unauthenticated.

If login fails, the cause is almost always a wrong site host, an expired or mistyped token, or an email that does not match the token's account. Fix and retry before continuing.

## Bind the repo to Jira in project-context.md

`/sdlc:init` writes `.claude/project/project-context.md`. These keys bind the repo to Jira and the base branch the pipeline targets:

| Key                | Value                                                             |
| ------------------ | ----------------------------------------------------------------- |
| `Jira project key` | Uppercase project key, e.g. `NA`. Stories are `<KEY>-<n>`.        |
| `Jira site`        | The authenticated host, e.g. `your-org.atlassian.net`.            |
| `Base branch`      | The integration branch PRs target, e.g. `main` or `develop`.      |
| `Project name`     | Repo/display name.                                                |
| `Package manager`  | `pnpm` / `npm` / `yarn` / `bun`, used to prefix tooling commands. |
| `Typecheck / Test` | The repo's typecheck and test commands, run in the review loop.   |

Set `Jira site` to the exact host you authenticated `acli` against, and `Jira project key` to a key `acli` can resolve (`acli jira project view <KEY>`). A mismatch between the site here and the site `acli` is logged into is the most common reason story fetches fail after init.

Run `/sdlc:init` to fill these interactively — it pre-fills `Jira site` from the authenticated host and validates the project key against `acli`. Re-running `/sdlc:init` on an already-initialised repo is safe (merge/confirm flow).

## Jira custom fields

`/sdlc:init` ends with a checklist of Jira custom fields you must configure by hand. The pipeline reads these fields but never creates them, so set them up on the project (key `<KEY>`) yourself:

1. **Story point estimate** (number) — the triage/route input. `/auto` uses it to decide whether a story skips spec+plan (lightweight) or runs the full flow. Add it to the story screen.
2. **AI Workflow** (single-select) with options `Full Auto`, `Auto`, and `Assisted` — controls whether a merged PR auto-merges or waits for a human. The field, when set, always wins.
   - No admin access to create the field? A story can opt in with an `AI-Workflow:<full-auto|auto|assisted>` label instead. With multiple such labels, the most conservative mode applies (`assisted` > `auto` > `full-auto`).

A project is ready once **Story point estimate** exists (always required) and an AI Workflow mode source is in place — the field, or the label convention on projects that cannot create it.

## Verify the connection

Confirm each integration before running the pipeline.

- GitHub auth:

  ```bash
  gh auth status
  ```

  Expect the target account listed as logged in with `repo` scope.

- Jira auth:

  ```bash
  acli jira auth status
  ```

  Expect your site and email reported as authenticated.

- Test story fetch — confirms the site, key, and auth all agree:

  ```bash
  acli jira workitem view <KEY>-<n> --json
  ```

  Replace `<KEY>-<n>` with a real story (e.g. `NA-12`). A returned work item confirms the binding.

- Custom fields readable:

  ```bash
  acli jira workitem view <KEY>-<n> --fields 'Story point estimate' --json
  acli jira workitem search --jql 'project = <KEY> AND "AI Workflow" is not EMPTY' --fields key
  ```

  The first returns the story-point value; the second lists any stories carrying an AI Workflow mode.

Once all four checks pass, run `/auto <KEY>-<n>` to put a story through the pipeline. See [docs/tutorials/getting-started-with-sdlc.md](../tutorials/getting-started-with-sdlc.md) for a guided first run.
