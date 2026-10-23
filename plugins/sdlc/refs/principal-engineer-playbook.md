# Principal Engineer Playbook (top-level orchestration)

<!-- notation: `:=` define, `->` leads-to, `⊆` drawn-from-set, ASSERT/ELSE guard, first-match-wins ordering. Full legend: refs/pseudocode-notation.md -->

The implementation-orchestration workflow for a Jira story. **This playbook is executed
INLINE by the top-level session** (via `/impl`, or `/auto`'s implementation phase) — it is
NOT dispatched as a subagent.

## Why inline

# rationale: refs/design-notes/inline-orchestration-rationale.md

You (the top-level session) play the Principal Engineer role: you coordinate only. You never
write feature code — domain agents (`platform-engineer`, etc.) do — and you never read source code
either: a question about the code goes to the agent that owns it, or to the reviewer. You own the
branch, the ordered domain-agent dispatch, per-phase pushes, and the PR. The post-implementation
**code-quality loop** (review → fix → learn → quality gate → AC verification) is owned by the **QA
Engineer** — at Step 6 you hand off, inline, to `${CLAUDE_PLUGIN_ROOT}/refs/qa-engineer-playbook.md`,
and create the PR only after QA returns a `clean` verdict.

## Inputs

- `<STORY-KEY>` — the Jira story key for this run
- `LIGHTWEIGHT` — `true` when the caller (triage) routed this story **lightweight**; default `false`.
  On `true` tasks derive **inline from the Jira story**. On `false` (full path) they come from the
  approved spec on the story branch — `SPEC := docs/superpowers/specs/<STORY-KEY>.md`, its
  `## Implementation tasks` (a plan doc `docs/superpowers/plans/<STORY-KEY>.md` on the branch, when one
  exists, is used instead).
- `WORK_KIND` — `defect` | `feature`, from the caller's inline `refs/triage.md`; default `feature`.
  `defect` → read `${CLAUDE_PLUGIN_ROOT}/refs/defect-variant.md` now (the systematic-debugging
  ladder) and use the `fix/` prefix. `LIGHTWEIGHT` and `WORK_KIND` are **orthogonal** — a lightweight
  **feature** keeps the normal feature ladder.

## Project constants

All project constants — base branch, quality gate, package manager, infra stage flag, active
agents — live in `.claude/project/project-context.md`. Read it first. This playbook references
them as tokens (`<BASE-BRANCH>`, `<BRANCH_PREFIX>/<STORY-KEY>`) and never hardcodes values.
Skip phases for agents marked **Standby** in project-context.

`BRANCH_PREFIX = (WORK_KIND == defect) ? "fix" : "feat"` — a convention, never a config token. The
commit type and PR title use the same `fix`/`feat`. Every story-branch reference below uses it.

---

## Step 0 — Nesting self-guard

Confirm the `Agent` tool is available to you. If it is not, you were dispatched as a subagent —
STOP and return the BLOCKED message from the principal-engineer profile. No skill loads are needed
here: this playbook carries its own dispatch contract (the review/quality skills belong to the
reviewer and verifier subagents QA dispatches). The defect path is the one exception
(`refs/defect-variant.md`).

## Step 1 — Pre-flight, sub-tasks, worktree (one call)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/pre-impl.sh <STORY-KEY> <BRANCH_PREFIX> <BASE-BRANCH> <LIGHTWEIGHT>
```

It runs, in order and stopping at the first failure: the full-path task-source check (the spec on
`origin/<BRANCH_PREFIX>/<STORY-KEY>` with its `Spec-Approved` label, or a legacy spec/plan doc), `BASE_SHA` (before branching — the
QA review-range start), the existing-PR check, the dependency gate (`scripts/dep-gate.sh`), the
sub-task probe, `scripts/worktree-setup.sh`, and the branch push. Keep `BASE_SHA`, `PR_STATE`,
`UI_BLOCKERS`, `SUBTASK_COUNT`, the `SUBTASK=` lines, `WORKTREE`, `NX_CACHE_DIRECTORY`.

- `RESULT=stop` → **STOP**; report `REASON=` verbatim. No branch, no agent dispatched. A dependency
  stop is reported as:
  ```
  BLOCKED — <STORY-KEY> cannot be implemented yet.
  Missing upstream work: <blocker-key(s) from the printed `PR: NO|unmerged` lines>.
  These must reach at least an open feat/* or fix/* PR (merged, for UI-Components) first.
  Next step: implement <blocker-key> first (or remove the Jira "Blocks" link if stale).
  ```
  The gate enforces the Jira dependency graph — never implement a story ahead of its blockers.
- `PR_STATE=open` → the existing branch is reused (the script merged the base in when
  `UI_BLOCKERS` is non-empty); a merged PR already stopped the run.
- `SUBTASK_COUNT > 0` → read `${CLAUDE_PLUGIN_ROOT}/refs/subtask-sequencing.md` and apply it in Steps
  4, 5 and 7. One branch per story, never per sub-task.

## Step 2 — Derive the task list (spec, plan, or — lightweight — the story)

**Full path:** read the plan doc in `$WORKTREE` when it exists; otherwise `SPEC` from the story branch
(`git show origin/<BRANCH_PREFIX>/<STORY-KEY>:<SPEC>`) — its `## Implementation tasks` lines are the
tasks. Group them by agent tag: `[database-administrator]`, `[platform-engineer]`,
`[ai-enablement-engineer]`, `[sync-engineer]`, `[web-engineer]`, `[mobile-engineer]`; drop Standby
phases with no tasks.

**Lightweight path:** fetch the story (summary, description, ACs) via
`${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` and turn it into an ordered, agent-tagged task list —
each piece of work to the **Active** agent that owns its files, in ladder order. Keep it
proportional (usually one or two agents). The **acceptance criteria are the completion contract**.

Design + Dev Notes: the spec's `## Design & Dev Notes` on the full path; on the lightweight path
resolve them from the story per `${CLAUDE_PLUGIN_ROOT}/refs/design-references.md` (missing design
path → STOP).

## Step 3 — Story worktree (done by Step 1)

The primary checkout **never** switches to the story branch: `pre-impl.sh` created it inside
`$WORKTREE`, reused for every phase, re-provisioned idempotently before any later fix round (QA
loop, `/review-fix`, `/sdlc:loop`), and torn down after the PR is raised (Step 7). Domain agents
never create branches or PRs.

## Step 4 — Dispatch domain agents (NON-NEGOTIABLE order, one at a time)

```
Phase 1 — [database-administrator]  schema + entities + migrations (ALWAYS FIRST; skip if Standby/no tasks)
Phase 2 — [platform-engineer]       backend infra + handlers + config
Phase 3 — [sync-engineer]           offline-sync rules + transactions (only if it has tasks)
Phase 4 — [web-engineer]            web pages/components (only if it has tasks)
Phase 5 — [mobile-engineer]         mobile screens (only if it has tasks)

[ai-enablement-engineer]            plugins/**, skills/**, AI-config surface (only if it has tasks)
                                     — dependency-free: may be dispatched at ANY point in the ladder
```

- Sequential only — never two domain agents at once, `ai-enablement-engineer` included (one writer
  on the single story branch).
- Each phase verified complete (Step 5) before the next is dispatched.

Dispatch with the `Agent` tool; the harness's **`isolation: "worktree"` param is NOT set** — the
orchestrator owns isolation via `$WORKTREE`:

```text
PLAN := $WORKTREE/docs/superpowers/plans/<STORY-KEY>.md   # /plan output, full path
no plan doc (lightweight, or a spec-driven full path) -> skip the slice; item 4 carries the ACs
                     verbatim, plus the SPEC path and this agent's task lines on the full path.
plan doc exists   -> slice := bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-slice.sh "$PLAN" phase <agent-name>
                     capture status first; STOP on exit 2; unset 5 keys; eval; STOP if TASKS==0
```

### Domain-agent prompt contract (agent starts cold — include ALL of this)

Hand the agent **paths, never pasted content** — it reads the spec, plan slice and refs itself.

1. **Mandatory first instruction (verbatim, with the real captured `$WORKTREE` substituted):**
   "Your working directory for ALL work is `<WORKTREE>` — `cd` into it before any read, edit,
   build, test, or commit. Do NOT operate in the primary checkout."
2. **Cache instruction (verbatim, with the real captured `$NX_CACHE_DIRECTORY` substituted):**
   "Before running any `nx` command (build/test/quality gate), export
   `NX_CACHE_DIRECTORY=<abs path>` so tasks hit the shared warm cache."
3. Story key, e.g. `<STORY-KEY>`.
4. Plan doc: `SLICE=` path from Step 4 (`## Plan slice`, `refs/domain-agent-handoff.md`). No plan
   doc: the story's ACs verbatim — plus, on the full path, the `SPEC` path and this agent's
   `## Implementation tasks` lines.
5. **Applicable override skills** — EITHER name the project skills to invoke (from the target
   agent's override, `.claude/project/agents/<agent-name>.md`, its skills section) with "Invoke these
   via the Skill tool BEFORE starting Task 1: `<skill-a>, <skill-b>`", OR state "No project skills
   apply for this task." Exactly one of the two.
6. The story's Design paths + Dev Notes verbatim (`${CLAUDE_PLUGIN_ROOT}/refs/design-references.md`)
   and any plan "grounding corrections" verbatim — short items only; spec sections by name, not by
   paste.
7. "Branch `<BRANCH_PREFIX>/<STORY-KEY>` already exists on remote and is checked out in `<WORKTREE>`
   (the working directory named in item 1). Do NOT create a new branch. Do your work there and
   commit."
8. "Do NOT create a PR — the orchestrator opens one after all phases and review are clean."
9. "Commit your changes (use the `conventional-commit` skill; scope from the directory name;
   **commit type `fix` on the defect path, `feat` otherwise**). Do NOT push — the orchestrator
   handles pushes." Sub-tasks → the `refs/subtask-sequencing.md` prompt addition.
10. "Write any admitted rule entries per the admission test in
    `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`'s rule-file flow and stage them with your
    commit — most dispatches admit nothing, and that's expected."
11. "Use the package manager and infra stage flag from project-context (Tooling) on every infra CLI command."
12. "Return exactly (per `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md` — 4 lines complete, 5 lines blocked):\n Status: complete|blocked\n Note: <one line if blocked, else omit>\n Summary: <one line — files changed, key entities/handlers touched>\n Skills loaded: <comma-separated override skill names | none>\n Rules applied: <rule-id>, <rule-id> | none"
13. "Context reuse: a path already read in full in this transcript is never re-read — see the `## Context reuse` section of ${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md." Also carries this phase's ledger row — `LEDGER_PHASE`, `LEDGER_AGENT`, `LEDGER_PLAN_SECTION`, `LEDGER_START_SHA`, `LEDGER_END_SHA`, `LEDGER_FILES_CHANGED`, `LEDGER_FILES_READ` (shape computed in Step 5), real values substituted — it names paths, not content.
14. "Bounded reads: Grep-first, then Read with `offset`/`limit` for files over ~400 lines — see the `## Bounded reads` section of `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`."

Never send just a task title.

## Step 5 — Phase completion verification (after EACH phase)

**Before dispatching the phase**, snapshot the primary checkout (spec §5) — a snapshot to diff
against, not an assertion; pre-existing dirt you didn't cause is never a violation:

```text
snap := bash ${CLAUDE_PLUGIN_ROOT}/scripts/assert-workspace-clean.sh snapshot <primary-root>
# -> PRIMARY_HEAD, PRIMARY_STATE_FILE, PRIMARY_PRE_DIRTY (keep PRIMARY_STATE_FILE for the assert call below)
PRIMARY_PRE_DIRTY == 'true' -> print the one-line warning below, then proceed  # never a STOP
```

`WARNING: primary checkout has pre-existing uncommitted changes unrelated to this story —
snapshotting and comparing, not blocking`.

**After the agent returns**, verify and push from `$WORKTREE` in one call:

```bash
git -C "$WORKTREE" log <BRANCH_PREFIX>/<STORY-KEY> --oneline -5; \
git -C "$WORKTREE" status --porcelain; \
git -C "$WORKTREE" push origin <BRANCH_PREFIX>/<STORY-KEY>; \
bash ${CLAUDE_PLUGIN_ROOT}/scripts/assert-workspace-clean.sh assert <primary-root> $PRIMARY_STATE_FILE
```

Record this phase's ledger row (a cache, never a required input — never a STOP if any of this fails):

```text
LEDGER_FILE := $(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)/phase-ledger.txt   # never $WORKTREE (D4)
before dispatch -> LEDGER_START_SHA := git -C "$WORKTREE" rev-parse HEAD
after the phase's commits -> LEDGER_END_SHA := git -C "$WORKTREE" rev-parse HEAD
LEDGER_FILES_CHANGED := names changed in $LEDGER_START_SHA..$LEDGER_END_SHA in $WORKTREE, sorted, comma-joined   # from git, never the agent's return (D2)
LEDGER_FILES_READ := the paths THIS dispatch prompt itself named
append the LEDGER_* block for this phase to LEDGER_FILE
```

```text
assert -> WORKSPACE_INTEGRITY ⊆ {OK, VIOLATED}, WORKSPACE_VIOLATION ⊆ {none, head-moved, worktree-changed, both}
non-zero exit / no WORKSPACE_INTEGRITY line -> STOP: cannot verify the primary checkout (see stderr)
WORKSPACE_INTEGRITY == 'VIOLATED' -> STOP: domain agent wrote to the primary checkout instead of $WORKTREE
`status --porcelain` non-empty -> STOP: $WORKTREE has stray uncommitted/untracked files — list them
no new commits since pre-dispatch HEAD -> STOP: agent failed silently (sub-tasks: one commit per sub-task touched)
push fails (conflict/auth) -> STOP, report
```

The assert is exact-match against the snapshot — a pre-dirty primary that stays at the same dirt
passes; only a *change* is a violation. A stray file in the shared `$WORKTREE` would otherwise be
swept into a LATER agent's commit as an unattributed change.

- `Status: blocked` → **STOP** immediately:
  ```
  BLOCKED at Phase N (<agent-name>).
  Reason: <Note>
  Next step: <what user must do>
  Remaining phases NOT dispatched.
  ```
  Never fix the blocker yourself. Unconditional — a blocked return carries no skill-coverage
  obligation (`Skills loaded: none` on an early abort is expected).
- **Verify `Skills loaded` covers the named set — `Status: complete` returns only.** Prompt named
  skills `S`: pass iff the line is present and **every** skill in `S` appears (missing line, empty,
  `none`, or a named skill absent → failure). Prompt declared none: pass iff the line is present and
  non-empty (`none`, or extra skills the agent chose to load). On failure → **redispatch that phase
  once** as a RETURN-CONTRACT redispatch: the work already landed; invoke the named skills now,
  verify the committed work against them, fix only if a skill mandates it, and re-emit a compliant
  return. Zero new commits is acceptable here (exempt from the silent-failure STOP). Still failing →
  **STOP and report**.
- **Verify the return carries `Rules applied:`** — `Status: complete` returns only. Absent or empty →
  the same RETURN-CONTRACT redispatch once. `none` is valid and expected.

Extract only `Status` / `Note` / `Summary` / `Skills loaded` / `Rules applied` from each agent
return; discard the rest.

## Step 6 — Hand off to the QA Engineer (inline)

**Execute `${CLAUDE_PLUGIN_ROOT}/refs/qa-engineer-playbook.md` inline**, in this same top-level session
(it dispatches the reviewer and domain fix agents, so it cannot be a subagent). Hand it:

- `<STORY-KEY>`, `BASE_SHA` (Step 1), the pushed `<BRANCH_PREFIX>/<STORY-KEY>` branch
- The Jira story summary + acceptance criteria, and the task source (`SPEC` or the plan doc path)
- `WORK_KIND` — `defect` re-points QA Step 7 to the regression-evidence contract
- The phase ledger (`LEDGER_FILE`) — **optional**: QA Step 3 falls back to git when absent (D3)

It returns `## QA verdict: <STORY-KEY>` with `Status: clean | blocked`.

- `Status: blocked` → **STOP**. Surface the QA `Blocked reason` exactly. No PR. No improvising.
- `Status: clean` → Step 6.5. QA already wrote learnings, ran the gate, and evidenced every AC —
  carry its verdict fields into your report; never repeat the work.

## Step 6.5 — Post-QA docs sync (on a clean QA verdict, before the PR)

Reached only on `Status: clean`. The branch is pushed and unmerged and `$WORKTREE` is still
provisioned, so a docs commit folds into the same impl PR. This wires in `sync`'s inline post-QA
dispatch variant (`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline-postqa.md` §25), diffing
story-branch-vs-base (§26).

**Manifest + change-size gate.** Deterministic — a script, not a dispatch:

```text
gate := bash ${CLAUDE_PLUGIN_ROOT}/scripts/docs-sync-gate.sh <STORY-KEY> <BRANCH_PREFIX> <BASE-BRANCH>
-> DOCS_GATE=skip-no-manifest|skip-no-tracked-files|dispatch|dispatch-unresolvable
bad exit/stdout/value -> dispatch-unresolvable
skip-* -> no-op rows below
dispatch* -> guard + dispatch below
```

**Primary-checkout guard — Step 5's machine check verbatim.** Snapshot first, dispatch the
`knowledge-engineer` post-QA variant with the live `$WORKTREE`, `$NX_CACHE_DIRECTORY`, the story
key, and `origin/<BASE-BRANCH>...<BRANCH_PREFIX>/<STORY-KEY>`. It **commits only**; **you** push
from `$WORKTREE` and re-run Step 5's assertions.

Classify into **exactly five** outcomes (rationale: `refs/design-notes/docs-sync-outcome-split.md`):

| Outcome at Step 6.5 | Class | Behaviour |
| --- | --- | --- |
| `.claude/project/docs-manifest.md` **absent** | **no-op** | No dispatch, no report line. Step 7. |
| Manifest present; the change-size gate finds the story touches no manifest-tracked path (an unresolvable set falls through to a dispatch, fail safe) | **no-op** | No dispatch. Step 8: `Docs sync: no manifest-tracked files touched — skipped`. |
| Manifest present; regen byte-identical **and** no `how-to` affected | **no-op** | No commit. Step 8: `Docs sync: no changes`. |
| **Docs-content failure** — regen error, docs push failure, or the agent returns `Status: blocked` | **WARN, never block** | Emit `WARNING: post-QA docs sync failed …`; still open the PR without the docs commit; Step 8 names the failure + the recovery pointer. |
| **Workspace-integrity failure** — primary HEAD moved, its porcelain changed, or `$WORKTREE` left with strays | **hard STOP** | Same shape as Step 5's guard; never open the PR. |

The docs commit, when made, is the last commit before the PR.

## Step 7 — Create the PR (only after QA returns `clean`)

Title keeps the parent `<STORY-KEY>`; head `<BRANCH_PREFIX>/<STORY-KEY>`. On the full path the PR
already carries the approved spec commit. Sub-tasks → body by file (`refs/subtask-sequencing.md`).
Create, mark ready, request Copilot (advisory — best-effort, never fails creation), and tear the
worktree down, in one call:

```bash
# sub-tasks: --body-file "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)/pr-body.md" in place of --body
PR_URL=$(gh pr view <BRANCH_PREFIX>/<STORY-KEY> --json url,state -q 'select(.state=="OPEN").url' 2>/dev/null)
[ -n "$PR_URL" ] || PR_URL=$(gh pr create \
  --title "[<STORY-KEY>] <story summary>" \
  --body "Implementation for <STORY-KEY>. All phases complete, review clean, quality gate passed." \
  --base <BASE-BRANCH> \
  --head <BRANCH_PREFIX>/<STORY-KEY>)
echo "PR_URL=$PR_URL"
[ -n "$PR_URL" ] && gh pr ready "$PR_URL"
gh pr edit "$PR_URL" --add-reviewer "@copilot" || echo "warn: @copilot reviewer not assigned — PR created regardless"
git worktree remove --force "$WORKTREE"
```

An empty `PR_URL` → **STOP** and report the `gh` error; an open PR for the branch is reused, so a
retry never fails on "already exists".

Capture `PR_URL` (full `https://github.com/...`). Removing the worktree never strands a later fix
round — QA, `/review-fix` and `/sdlc:loop` re-provision it idempotently (`worktree-setup.sh`).

## Step 8 — Final report (to the caller / user)

Carry the QA verdict fields — never re-derive them. `Docs sync:` reports Step 6.5's outcome.

```
## <Feature|Fix>: <name>  (Branch: <BRANCH_PREFIX>/<STORY-KEY>)   # "Fix" on the defect path, "Feature" otherwise
### Phases: <agents that ran + one-line summaries>
### QA: rounds <N>; fixed <Critical/Important list>; minor noted <list>; ACs <met — all N evidenced>
### Quality gate: typecheck pass | tests pass   (QA evidence)
### Docs sync: <no changes | committed on the branch | no manifest-tracked files touched — skipped | WARN: <failure> — recover with `/sdlc:docs sync <STORY-KEY>` after merge | skipped (no docs manifest)>
### PR: <PR_URL>
### Status: all phases complete, QA verdict clean, gate passed, PR ready.
```

## Constraints

- Never start a story whose Jira blockers lack a `feat/*` or `fix/*` PR — Step 1 STOPs (no branch, no agents).
- Never skip the dependency order; never run two domain agents at once.
- YOU create the branch and push; domain agents only commit.
- Never read or grep source code yourself — ask the owning agent or the reviewer (defect phases 1–2 excepted, `refs/defect-variant.md`).
- The code-quality loop is owned by the QA Engineer (Step 6) — run it inline, never duplicate it.
- PR opened by YOU only after QA returns `Status: clean`.
- Any agent `blocked`, or a QA `Status: blocked` → stop, report immediately, no PR.
- Never implement feature code yourself — coordinate only.
- Never dispatch a `principal-engineer` (or `qa-engineer`) subagent — run both playbooks inline.
