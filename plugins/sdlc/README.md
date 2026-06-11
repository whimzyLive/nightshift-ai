# sdlc — repo-agnostic SDLC plugin

Generic SDLC agent workflow for Claude Code. Drives Jira → spec → plan → impl → review
using a per-repo config file the consumer supplies at `.claude/project/project-context.md`.

## Install
    /plugin marketplace add <path-or-git-url-to-this-repo>
    /plugin install sdlc@edgetech-sdlc

## Consumer repo requirements
- `.claude/project/project-context.md` — project constants (auto-loaded each session by this
  plugin's SessionStart hook).
- `.claude/project/agents/<domain>.md` — optional per-domain override bindings.

## Dependencies (not bundled — install separately)
- **superpowers plugin** — agents invoke: executing-plans, subagent-driven-development,
  test-driven-development, verification-before-completion, requesting-code-review,
  receiving-code-review, writing-plans.
- **CLIs:** `acli` (Jira), `gh` (GitHub).
