# Resolving the working issue's mode

Referenced from `commands/auto.md`'s **Loop-after-raise** procedure (the "Resolving the working
issue's mode" pointer) and `refs/epic-orchestration.md` E0's `epicFallback` ladder — both resolve
mode via the SAME shared script; this file is the single source of truth for the ladder itself.

The terminal action (auto-merge vs leave for a human) depends on the story's AI workflow mode. Do
**not** parse `acli workitem view` text output — that format is not stable across acli
versions/flags, and a parse miss would silently disable Full Auto. Instead probe **definitively**
with a JQL match (the repo's established custom-field-read pattern — see `refs/jira-fetch.md`), so
auto-merge is enabled **only** when Jira itself confirms the mode is `Full Auto`.

The mode has two sources, in strict precedence order:

1. **The `"AI Workflow"` custom field** — always wins when it is set to anything.
2. **An `AI-Workflow:<mode>` label fallback** — consulted **only when the field is unset or the
   field doesn't exist on the instance**. Projects that cannot add custom fields opt in via a label
   instead: `AI-Workflow:full-auto`, `AI-Workflow:auto`, or `AI-Workflow:assisted` (lowercase mode
   tokens). When a story carries **multiple** `AI-Workflow:*` labels, the **most conservative** one
   wins (`assisted` > `auto` > `full-auto`) — the label probes inside `resolve-ai-workflow-mode.sh`
   check most-conservative first, so the ladder's order encodes that rule.

`MODE` always resolves to a **real mode string** (`Full Auto` / `Auto` / `Assisted`), or empty when
**neither source is set** — never a placeholder — because callers interpolate it into
operator-facing text (e.g. the epic loop's E2b gate prompt via `storyMode(S)`).

Resolve it via the shared ladder script (collapses this ladder and E0's `epicFallback` ladder into
one implementation — NA-86 A6):

```bash
eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-ai-workflow-mode.sh STORY_KEY)"
# -> sets MODE ('Full Auto' | 'Auto' | 'Assisted' | '') and MODE_SOURCE (additive
#    observability only — D9, no caller branches on it)
```

`MODE="Full Auto"` is the **only** value that enables auto-merge. Any other outcome (`Auto`,
`Assisted`, empty, or a JQL/auth error that yields no match) → the **human-merge** path. Defaulting
to the human path is the safe failure mode: a transient read error must never trigger an unattended
merge. (The `"AI Workflow"` field name is the consuming repo's single-select; the JQL match is
case- and format-stable, unlike scraping view output. On an instance where the field doesn't exist
at all, the field probes error → no match → the label probes still run, which is exactly the
fallback's target case. The label tokens deliberately mirror the mode values the consuming repo's
trigger service resolves from the same labels, so webhook-side triggering and `/auto`-side gating
agree.)
