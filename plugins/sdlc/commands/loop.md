---
description: After a PR is raised, stay active and drive the Copilot review-and-fix cycle to completion. Polls the PR every minute for unresolved Copilot review comments, runs /review-fix on each pass, and exits cleanly only when all Copilot comments are resolved AND all required status checks pass. Halts and surfaces the failure if a /review-fix run errors. Does NOT merge the PR and does NOT process non-Copilot review comments.
---

Drive the post-PR review-fix cycle for **`$ARGUMENTS`** (a GitHub PR number or URL) to completion.
This command STAYS ACTIVE after a PR exists: it polls for Copilot review feedback, applies fixes
via `/review-fix`, and only exits when Copilot's comments are all resolved and the PR's required
checks are green. It does NOT merge the PR (out of scope) and ignores non-Copilot reviewers.

Repo slug: read `<owner>/<repo>` from `.claude/project/project-context.md` (GitHub -> Org/repo).

## Steps

1. **Resolve the target PR** from `$ARGUMENTS`:
   `gh pr view <PR> --json number,headRefName,baseRefName,url,state`
   If the PR is not OPEN -> STOP: "PR <PR> is not open — nothing to loop on".

2. **Confirm Copilot is the reviewer** (AC-1). If `@copilot` is not already a requested reviewer,
   request it best-effort (`gh pr edit <PR> --add-reviewer @copilot`), then enter the polling phase
   WITHOUT exiting the session.

3. **Poll loop (1-minute interval)** (AC-2, AC-5). On each iteration:
   - Probe status into the session temp dir (never /tmp, never inline JSON):
     ```bash
     dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
     bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-loop-status.sh <PR> "$dir/loop-copilot.json"
     ```
     Read the `loop-status:` line: `unresolved-copilot`, `checks-pending`, `checks-failing`, `checks-passing`.
   - **Print progress to stdout** (AC-5): iteration number, unresolved-copilot count, checks pending/failing/passing.
   - **Exit condition (AC-3):** if `unresolved-copilot == 0` AND `checks-failing == 0` AND
     `checks-pending == 0` -> the loop is DONE; break and go to Report.
   - **Fix pass (AC-2):** if `unresolved-copilot > 0`, run `/review-fix <PR>` INLINE (apply the
     review-fix command's steps in this session; do NOT dispatch a subagent and do NOT let
     review-fix run its own session-complete — `/loop` owns the single release). On success,
     continue the loop (next poll picks up newly-resolved threads + new check runs).
   - **Wait** one minute before the next iteration (poll interval):
     ```bash
     sleep 60
     ```

4. **Halt on failure (AC-4).** If a `/review-fix` pass errors or returns `Status: blocked`
   (cannot apply a fix), STOP the loop immediately: print the failure (which comment / what error)
   to stdout and EXIT non-clean — do NOT silently continue to the next poll iteration.

## Report

On clean exit: print the final `loop-status:` line, the number of poll iterations, total Copilot
comments resolved across the run, and the green-checks confirmation. On halt (AC-4): print the
failing iteration and the surfaced `/review-fix` error/blocked reason — do not improvise around it.

**IMPORTANT:** `/loop` never merges the PR and never touches `/spec`, `/plan`, `/impl`, or `/auto`
PR-raising logic. It only drives review + review-fix + check-gating on an already-open PR.

## Final action — release the session (required)

After everything above is complete (clean exit, or a terminal STOP/halt surfaced to the user), run
this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It signals the automation worker to release this session's slot. Outside the worker
(`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

GitHub PR number or URL:
$ARGUMENTS
