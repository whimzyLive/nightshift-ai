---
description: Run ONLY the QA code-quality loop (review → fix → re-review until clean) without re-running the implementation lifecycle. With a story key → reviews its fix/ or feat/<STORY-KEY> branch (whichever exists) against the plan + ACs. With no key → Diff mode: reviews the current working changes vs develop. Runs the QA Engineer playbook inline. Not for implementing.
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

1. **Resolve the review branch by probing BOTH prefixes (git-only — do NOT fetch `issuetype.name`).**
   `/review` is a **standalone consumer**: it has no upstream `WORK_KIND`, and the impl branch already
   encodes how the work was built — so the branch that exists is authoritative. A Jira fetch here
   would re-introduce the fail-safe-to-`feature` false-STOP the branch-probe exists to avoid.

   ```bash
   # Fetch each candidate INDEPENDENTLY — a single combined `git fetch` of all three refs aborts
   # whole if ANY ref is absent (the normal case: only one prefix exists), which would leave the
   # other prefix's remote-tracking ref stale/absent and yield a false "neither exists" STOP. Per-ref
   # fetch with `|| true` updates whichever refs DO exist and ignores the misses.
   git fetch origin develop 2>/dev/null || true
   git fetch origin "fix/<STORY-KEY>"  2>/dev/null || true
   git fetch origin "feat/<STORY-KEY>" 2>/dev/null || true
   FIX_EXISTS=$(git rev-parse --verify -q origin/fix/<STORY-KEY>  >/dev/null 2>&1 && echo yes || echo no)
   FEAT_EXISTS=$(git rev-parse --verify -q origin/feat/<STORY-KEY> >/dev/null 2>&1 && echo yes || echo no)
   ```

   Decide the branch:
   - **exactly one exists** → review it.
   - **neither exists** → **STOP**: "no `fix/<STORY-KEY>` or `feat/<STORY-KEY>` branch for `<STORY-KEY>` — run `/impl` first".
   - **both exist** (an abandoned attempt on one prefix + real work on the other) → do **NOT** blindly
     prefer `fix/`. Pick the branch that has an **open PR** (`gh pr list --head fix/<STORY-KEY> --state open`
     / `--head feat/<STORY-KEY> --state open` — the active-work signal). If still ambiguous (both or
     neither have an open PR) pick the **most-recently-pushed** (`git log -1 --format=%ct origin/<branch>`)
     **and emit a WARNING** naming both branches — never silently review a stale branch.

   Set `RESOLVED_BRANCH` to the chosen `fix/<STORY-KEY>` or `feat/<STORY-KEY>`, then:

   ```bash
   BASE_SHA=$(git merge-base origin/develop "origin/$RESOLVED_BRANCH")
   ```

2. **Derive `WORK_KIND` from the resolved branch prefix** — `fix/` ⇒ `defect`, `feat/` ⇒ `feature`.
   This is the single source for `WORK_KIND` on this already-produced-work path; it is **not** a second
   predicate competing with `refs/triage.md`'s issuetype check (that gates _routing_, upstream). The
   only way they could disagree is an upstream misroute (a Bug built on `feat/`), which is a separate
   defect `/review` does not re-litigate by re-fetching the issue type.
3. Fetch the story with `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` (`<KEY>=<STORY-KEY>`) for the summary and
   **acceptance criteria** — the loop checks the code against the ACs.
4. **Execute `${CLAUDE_PLUGIN_ROOT}/refs/qa-engineer-playbook.md` inline in Story mode**, passing
   `<STORY-KEY>`, `BASE_SHA`, `WORK_KIND` (from step 2), the `RESOLVED_BRANCH`, and the story summary +
   ACs. **`WORK_KIND` is required**: on `defect` the QA playbook's Step-7 verification requires the
   defect regression-evidence contract instead of the feature AC/plan checklist — without it a defect
   branch would silently pass the feature gate. Fix commits are pushed to `RESOLVED_BRANCH` (landing on
   its open PR, if any).

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
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It signals the automation worker to release this session's slot. Outside the worker
(`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Jira story key (optional — omit for Diff mode):
$ARGUMENTS
