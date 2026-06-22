# sdlc — repo-agnostic SDLC plugin

Generic SDLC agent workflow for Claude Code. Drives Jira → spec → plan → impl → review
using a per-repo config file the consumer supplies at `.claude/project/project-context.md`.

`/auto` triages by complexity first: **small stories** (≤ the configurable lightweight threshold,
default 3 points) skip spec+plan entirely and go **straight to implementation** (tasks derived inline
from the ticket); the full spec → plan → review-gate flow is reserved for larger stories.

## Install
    /plugin marketplace add <path-or-git-url-to-this-repo>
    /plugin install sdlc@nightshift

## Consumer repo requirements
- `.claude/project/project-context.md` — project constants (auto-loaded each session by this
  plugin's SessionStart hook).
- `.claude/project/agents/<domain>.md` — optional per-domain override bindings.
- Add `.claude/.sdlc-plugin-root` to the repo's `.gitignore` (see below).

## Plugin-path resolution (`.claude/.sdlc-plugin-root`)
`${CLAUDE_PLUGIN_ROOT}` is only available to Claude Code hooks and slash commands — it is **not**
injected into subagents. Since the SDLC agents must read bundled refs and run bundled scripts,
the SessionStart hook (which does have the variable) writes the resolved absolute plugin root to
`.claude/.sdlc-plugin-root` in the consumer repo each session. Every agent reads that one-line
marker from cwd and substitutes it wherever its instructions reference `${CLAUDE_PLUGIN_ROOT}`.
The file is a regenerated per-session cache — **gitignore it**.

## Dependencies
- **superpowers plugin** — **auto-installed.** Declared as a cross-marketplace dependency
  (`superpowers@claude-plugins-official`), so `/plugin install sdlc@nightshift` reuses an existing
  superpowers install or pulls it from the official marketplace. Agents invoke its skills:
  executing-plans, subagent-driven-development, test-driven-development,
  verification-before-completion, requesting-code-review, receiving-code-review, writing-plans.
- **CLIs (install manually — not plugins):** `acli` (Jira), `gh` (GitHub).
