---
description: Triage a Jira story's complexity and return a deterministic TRIAGE=lightweight|full / STORY_POINTS= routing block so /impl and /auto route consistently. Reads existing story points; never sets them.
---

Triage the Jira story **`$ARGUMENTS`** and emit the shared routing contract so callers (`/impl`, `/auto`, or a human) decide whether the story needs an approved spec first or can go straight to implementation.

`/triage` runs `${CLAUDE_PLUGIN_ROOT}/scripts/triage.sh`, which applies `${CLAUDE_PLUGIN_ROOT}/refs/triage.md` (threshold, story points, work kind, decision table) deterministically. Do not compute any part of the route yourself.

## Steps

1. Parse `$ARGUMENTS` → `STORY_KEY`.
2. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/triage.sh STORY_KEY` and print its output verbatim: the optional `WARNING:` line, then `WORK_KIND=`, `TRIAGE=`, `STORY_POINTS=`, then `THRESHOLD=` (the threshold it used).
3. A non-zero exit means a Jira/`acli` failure: **STOP** and surface the script's error. It prints no `WORK_KIND=`/`TRIAGE=` block then, so never state or guess a route.

## Final action — release the session (required when run standalone)

This step applies only when `/triage` is the **top-level** command the harness drove. When triage
runs **inside** `/auto` or `/impl`, those parents run `scripts/triage.sh` directly (they do NOT invoke
this command) and own the single session release at the very end — so this final action never runs
nested.

After **everything above is complete** (success, or a terminal STOP surfaced to the user), run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Jira story key (e.g. CER-123):
$ARGUMENTS
