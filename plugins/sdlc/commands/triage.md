---
description: Triage a Jira story's complexity and return a deterministic TRIAGE=lightweight|full / STORY_POINTS= routing block so /impl and /auto route consistently. Reads existing story points; never sets them.
---

Triage the Jira story **`$ARGUMENTS`** and emit the shared routing contract so callers (`/impl`, `/auto`, or a human) decide whether the story needs the full spec+plan ceremony or can go straight to implementation.

`/triage` is a thin wrapper over `${CLAUDE_PLUGIN_ROOT}/refs/triage.md` — it does not re-state the threshold or decision logic; it applies the ref and prints the contract block.

## Steps

1. Parse `$ARGUMENTS` → `STORY_KEY`.
2. **Resolve the threshold.** Read `.claude/project/project-context.md` (already the mandated first read for every SDLC command) and resolve the lightweight threshold `T` per `${CLAUDE_PLUGIN_ROOT}/refs/triage.md` "Threshold resolution" — per-repo `## Triage` override if present, else the built-in default `3`. A malformed override falls back to `3` and emits a `WARNING:` line.
3. **Read the story points.** Apply the `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` "Reading story points" protocol for `STORY_KEY` (JQL-probe BOTH `Story point estimate` and `Story Points`; `missing` only when neither is populated). If the `acli` fetch fails (auth/DNS), **STOP** and surface the error — do NOT guess a route.
4. **Decide.** Apply the `${CLAUDE_PLUGIN_ROOT}/refs/triage.md` decision table to compute `TRIAGE` (`points <= T ⇒ lightweight`, `points > T ⇒ full`, `missing ⇒ full`).
5. **Emit the contract block** exactly per the ref's output contract — the two required lines, preceded by an optional `WARNING:` line only on the missing-points or malformed-threshold paths:
   ```
   TRIAGE=lightweight|full
   STORY_POINTS=N|missing
   ```
   On the `acli`-failure STOP path (Step 3), emit **no** `TRIAGE=` block — surface the error instead, so callers never parse a guessed route.

## Final action — release the session (required when run standalone)

This step applies only when `/triage` is the **top-level** command the harness drove. When triage
runs **inside** `/auto` or `/impl`, those parents apply `refs/triage.md` inline (they do NOT invoke
this command) and own the single session release at the very end — so this final action never runs
nested.

After **everything above is complete** (success, or a terminal STOP surfaced to the user), run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Jira story key (e.g. CER-123):
$ARGUMENTS
