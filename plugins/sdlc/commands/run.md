---
description: Run one or more Jira stories as background /sdlc:auto sessions, then watch them. Validates keys and blockers, launches runs staggered within the concurrency guidance, arms a 10-minute monitor tick that push-notifies on needs-human, stalled and done, and prints one table of how to attach, log and stop each run.
---

Run the stories in **`$ARGUMENTS`** in the background. Operating guide:
`${CLAUDE_PLUGIN_ROOT}/refs/bg-runs.md` (read it first; it holds the run rules, concurrency guidance,
resume procedure and the monitor tick prompt). This command does not restate them.

## Input

`<KEY> [<KEY> ...] [--max N]`

- `KEYS` := every token of `$ARGUMENTS` that is not a flag, in the order given. Each must look like a
  Jira key (`ABC-123`). Anything else -> **STOP** and name the bad token.
- `MAX` := the `--max N` value, else the `Max parallel runs` token of `.claude/project/project-context.md`
  (`## Pipeline`), else `2`.

## Steps

1. **Read context.** Read `.claude/project/project-context.md`. Run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1`. Resolve `DONE_STATUS` (the
   `Pipeline done status` row) and the lightweight threshold `T` per `${CLAUDE_PLUGIN_ROOT}/refs/triage.md`
   "Threshold resolution".
2. **Check each key.** For every key:
   - Existing run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/bg-status.sh KEY`. Verdict `RUNNING`,
     `STALLED` or `NEEDS_HUMAN` -> do not launch a second session; list it as `already running` and
     track it. Verdict `DONE` -> skip it.
   - Blockers: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/dep-gate.sh KEY`, read only its `BLOCKERS=` and
     `DESIGN_BLOCKERS=` lines (the gate's STOP for a blocker without a PR is expected here). For each
     blocker read its Jira status (`acli jira workitem view <blocker> --fields status --json`,
     `.fields.status.name`). Any blocker not at `DONE_STATUS` -> the key is `waiting` on those blockers,
     named in the table. A key listed in `DESIGN_BLOCKERS=` is the Epic's open Design story: the reason
     reads `blocked by the Design story <key> — run /sdlc:design <EPIC> --final` (`<EPIC>` is the gate's
     `EPIC=` line), and no run can close it, a person does. A `REASON=` saying KEY is itself the Design
     story -> never launch it; list it as `design story: closed by a person`. **Never launch a story
     with an open blocker.** A story with no parent epic has no derivable blockers; say so in the table.
   - Size: read the story points per `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` "Reading story points"
     and apply `${CLAUDE_PLUGIN_ROOT}/refs/triage.md`. A `full` story (points above `T`, or missing) will
     stop for spec approval: mark it `full: stops for spec approval` so the user knows to expect a
     `NEEDS YOU:` push and answer it. A bug or a `lightweight` story runs straight through.
3. **Launch.** For each launchable key, in order, while live runs < `MAX` (concurrency guidance in the
   ref: check `uptime` first, hard stop at a 1-minute load of 20): run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-bg.sh KEY` in its own background Bash call, then wait 30
   seconds before the next. Capture the session id from `claude agents --json --cwd <repo root>` (the
   entry named `KEY`). Keys beyond `MAX` or with open blockers stay `waiting`; the tick launches them.
   If two keys in the batch touch the same files, launch the second only after the first has a PR.
4. **Arm the monitor tick.** Create the recurring wakeup exactly as the "Monitor tick" section of the
   ref says: `CronCreate`, cron `4-59/10 * * * *`, `recurring: true`, the prompt template with the
   tracked keys and the waiting stories filled in. Say that it is session-only and expires after 7 days.
5. **Print one table**, one row per key:

   | Key | State | Session | Size | Attach | Logs | Stop |
   | --- | ----- | ------- | ---- | ------ | ---- | ---- |

   `State` is `started`, `already running`, `waiting on <blockers>` (with `blocked by the Design story`
   where that is the reason) or `done`. `Attach` is
   `claude attach KEY`, `Logs` is `claude logs KEY`, `Stop` is `claude stop <session id>`. Below the
   table state the concurrency used (`N of MAX`) and that decision questions are asked here, in this
   session, when a `NEEDS YOU` push arrives.

## Final action — release the session (required when run standalone)

After everything above is complete (or a terminal STOP was surfaced), run as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for; outside the worker
(`SDLC_SESSION_KEY` unset) it is a silent no-op.

Stories to run (e.g. ABC-123 ABC-124 --max 2):
$ARGUMENTS
