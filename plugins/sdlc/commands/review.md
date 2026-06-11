---
description: Run ONLY the QA code-quality loop (review → fix → re-review until clean) without re-running the implementation lifecycle. With a story key → reviews its feat/<STORY-KEY> branch against the plan + ACs. With no key → Diff mode: reviews the current working changes vs develop. Runs the QA Engineer playbook inline. Not for implementing.
---

Run the QA Engineer's code-quality loop (review → fix → re-review until clean), then report the
verdict. This NEVER re-implements, creates a branch, or opens a PR.

**Do NOT dispatch a `qa-engineer` subagent.** Claude Code blocks subagent → subagent nesting, so
a dispatched qa-engineer cannot dispatch the `agent-skills:code-reviewer` subagent or the domain
fix agents it needs. You play the QA Engineer role directly, in the top-level session.

## Pick the mode from `$ARGUMENTS`

- **`$ARGUMENTS` is a Jira story key (e.g. `<STORY-KEY>`) → Story mode.**
- **`$ARGUMENTS` is empty → Diff mode** (review the current change set; no ticket, no plan, no AC).

---

### Story mode — `/review <STORY-KEY>`

1. Resolve and verify the branch:
   ```bash
   git fetch origin feat/<STORY-KEY> develop
   git rev-parse --verify origin/feat/<STORY-KEY> \
     || { echo "STOP: no feat/<STORY-KEY> branch — run /impl first"; exit 1; }
   BASE_SHA=$(git merge-base origin/develop origin/feat/<STORY-KEY>)
   ```
2. Fetch the story with `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` (`<KEY>=<STORY-KEY>`) for the summary and
   **acceptance criteria** — the loop checks the code against the ACs.
3. **Execute `${CLAUDE_PLUGIN_ROOT}/refs/qa-engineer-playbook.md` inline in Story mode**, passing
   `<STORY-KEY>`, `BASE_SHA`, the `feat/<STORY-KEY>` branch, and the story summary + ACs. Fix
   commits are pushed to `feat/<STORY-KEY>` (landing on its open PR, if any).

### Diff mode — `/review` (no key)

1. Compute the review range over the current change set (committed-but-unmerged **and**
   uncommitted working-tree changes):
   ```bash
   git fetch origin develop
   BASE_SHA=$(git merge-base origin/develop HEAD)
   git --no-pager diff --stat ${BASE_SHA}            # confirm there IS a change to review
   ```
   If the diff is empty → STOP: "nothing to review — working tree matches develop".
2. **Execute `${CLAUDE_PLUGIN_ROOT}/refs/qa-engineer-playbook.md` inline in Diff mode**, passing `BASE_SHA` and
   the current branch/working tree (no story key, no plan, no ACs). Per the playbook's Diff mode:
   the reviewer reviews the **single-point working-tree diff `git diff <BASE_SHA>` plus any
   untracked files** — NOT a `BASE_SHA..HEAD_SHA` commit range, which would miss uncommitted edits;
   the reviewer's requirements are the change's own intent (commit subjects + changed-file
   summary); fixes are applied in the **working tree and never pushed**; the AC/plan checklist and
   learnings-memory steps are skipped.

---

## Report (both modes)

Report the QA verdict block verbatim (Status clean|blocked, rounds, fixes, gate evidence — plus
AC check in Story mode). On `blocked`, surface the reason — do not improvise around it.

**IMPORTANT:** This makes real code changes (fix commits / working-tree edits). PR creation is
out of scope — that stays with `/impl`. If the loop returns `Status: blocked`, STOP and surface it.

## Final action — release the session (required)

After everything above is complete (success, or a terminal STOP/blocked surfaced to the user),
run this as your very last action:

```bash
bash ./${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It signals the automation worker to release this session's slot. Outside the worker
(`JUGAAD_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Jira story key (optional — omit for Diff mode):
$ARGUMENTS
