# Principal Engineer Playbook (top-level orchestration)

The implementation-orchestration workflow for a Jira story. **This playbook is executed
INLINE by the top-level session** (via `/impl`, or `/auto`'s implementation phase) — it is
NOT dispatched as a subagent.

## Why inline (read this first)

Claude Code blocks subagent → subagent dispatch (nesting is one level deep, by design). The
orchestrator's entire job is to dispatch domain agents with the `Agent` tool, so it MUST run
where that tool works: the top-level session. If you dispatch `principal-engineer` as a
subagent it will be unable to dispatch anyone and will return blocked. **Do not dispatch a
`principal-engineer` subagent. Run these steps yourself in the main loop.**

You (the top-level session) play the Principal Engineer role: you coordinate only. You never
write feature code yourself — domain agents (`platform-engineer`, etc.) write code. You own
branch creation, the ordered domain-agent dispatch, per-phase pushes, and the PR. The
post-implementation **code-quality loop** (review → fix → learn → quality gate → AC
verification) is owned by the **QA Engineer** — at Step 6 you hand off, inline, to
`${CLAUDE_PLUGIN_ROOT}/refs/qa-engineer-playbook.md`, and create the PR only after QA returns a `clean`
verdict.

## Inputs

- `<STORY-KEY>` — the Jira story key for this run
- `LIGHTWEIGHT` — `true` when the caller (triage) routed this story **lightweight**; default `false`.
  On `true` the plan doc is **optional** and tasks are derived **inline from the Jira story** (Step 1
  skips the plan-file STOP; Step 2 derives from the story). On `false` (full path) the merged plan
  doc is required, exactly as before.
- `WORK_KIND` — `defect` | `feature`, handed in by the caller (`/auto`/`/impl` apply `refs/triage.md`
  inline first, so `WORK_KIND` is already resolved); default `feature` when absent. `WORK_KIND=defect`
  activates the **systematic-debugging defect variant** of the phase ladder (Step 4) and selects the
  `fix/` branch prefix. `LIGHTWEIGHT` and `WORK_KIND` are **orthogonal**: `LIGHTWEIGHT` controls only
  plan-doc-optional behaviour; `WORK_KIND` controls debugging activation + branch prefix. A lightweight
  **feature** (`LIGHTWEIGHT=true`, `WORK_KIND=feature`) keeps the normal feature ladder — it is never
  misrouted into debugging.
- Plan path derived deterministically: `docs/superpowers/plans/<STORY-KEY>.md`

## Project constants

All project constants — base branch, quality gate, package manager, infra stage flag, active
agents — live in `.claude/project/project-context.md`. Read it first. This playbook references
them as tokens (`<BASE-BRANCH>`, `<BRANCH_PREFIX>/<STORY-KEY>`) and never hardcodes values.

Skip phases for agents marked **Standby** in project-context.

### Branch-prefix convention (derived from `WORK_KIND`)

The implementation branch prefix is a **convention computed from `WORK_KIND`**, never a per-repo
config token:

```
BRANCH_PREFIX = (WORK_KIND == defect) ? "fix" : "feat"
```

→ a defect implements on `fix/<STORY-KEY>`; a feature on `<BRANCH_PREFIX>/<STORY-KEY>`. Correspondingly the
conventional-commit type and PR title use `fix` on the defect path, `feat` on the feature path
(Steps 4, 7). Throughout this playbook `<BRANCH_PREFIX>/<STORY-KEY>` denotes the story branch —
resolve it from the `WORK_KIND` in hand (no Jira fetch, no config token). Every story-branch
reference below (pre-flight PR-exists check, branch create/push, domain-agent prompt contract,
push/verify, PR `--head`, final report) uses this derived prefix.

---

## Step 0 — Required skills

**Nesting self-guard (first):** confirm the `Agent` tool is available to you. If it is not, you
were dispatched as a subagent — STOP and return the BLOCKED message from the principal-engineer
profile. Do not orchestrate or implement anything yourself.

Invoke, in order, before dispatching anything:

1. `executing-plans`
2. `subagent-driven-development`

(The review/quality skills — `requesting-code-review`, `receiving-code-review`,
`verification-before-completion` — are owned and invoked by the QA Engineer at Step 6, not here.)

**On the defect path (`WORK_KIND=defect`) — also confirm `systematic-debugging` is invocable.**
`systematic-debugging` is a **global superpowers skill**, intentionally **not** listed in the
plugin's `skills-manifest.md` / `skills-map.yml` — that absence is **by design** (the skill is not
stack-gated), NOT a signal it is missing. Before phase 1 of the defect variant (Step 4), confirm the
skill loads. If it is genuinely uninvocable → **STOP and report** (`blocked`); never silently skip
the debugging phases. On the feature path this skill is not used.

## Step 1 — Pre-flight checks

```bash
# 1. Plan must exist (merged to develop) — REQUIRED on the full path ONLY.
#    On the lightweight path (LIGHTWEIGHT=true) a missing plan doc is expected and NOT a STOP;
#    Step 2 derives the task list inline from the Jira story instead.
if [ "${LIGHTWEIGHT:-false}" != "true" ]; then
  test -f "docs/superpowers/plans/<STORY-KEY>.md" \
    || { echo "STOP: plan not found — merge the plan PR first"; exit 1; }
fi

# 2. Sync develop, capture base SHA BEFORE branching (needed for review range)
git fetch origin develop
BASE_SHA=$(git rev-parse origin/develop)

# 3. No implementation PR already open
gh pr list --search "<BRANCH_PREFIX>/<STORY-KEY>" --json number,title,headRefName,state

# 4. Dependency gate — every story that BLOCKS this one must already have a feat/* OR fix/* PR.
#    Deterministic, single statically-analyzable call (allowlisted Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)).
#    The script resolves the parent epic, derives blockers by sibling-inversion
#    (a sibling S blocks <STORY-KEY> iff S's links have outwardIssueKey == <STORY-KEY>),
#    and verifies each blocker has a feat/<blocker> OR fix/<blocker> PR (dual-prefix: a blocker that
#    shipped as a defect on fix/<blocker> counts). acli is the only source of truth —
#    any acli query error => GATE=STOP. See ${CLAUDE_PLUGIN_ROOT}/scripts/dep-gate.sh.
#    NOTE: resolving the epic REQUIRES `acli workitem view KEY --fields parent` — the default
#    `view --json` strips `parent` and returns empty (this was a real gate-failure bug).
bash ${CLAUDE_PLUGIN_ROOT}/scripts/dep-gate.sh <STORY-KEY>   # exit 0 = GATE=PASS, exit 1 = GATE=STOP (REASON= printed)
```

- Plan missing on the **full** path (`LIGHTWEIGHT` unset/false) → **STOP**, tell user to merge the plan PR. On the **lightweight** path a missing plan doc is expected — **do not STOP**; proceed (Step 2 derives tasks from the story).
- Implementation PR already merged → **STOP**, report it's already done.
- An open `<BRANCH_PREFIX>/<STORY-KEY>` PR/branch already exists → reuse it (check it out); do not create a duplicate.
- **Any blocker has no `feat/<blocker>` or `fix/<blocker>` PR (open or merged) → STOP the entire flow and REJECT.** Do not create a branch, do not dispatch any domain agent. Report to the user:
  ```
  BLOCKED — <STORY-KEY> cannot be implemented yet.
  Missing upstream work: <blocker-key(s) with no feat/* or fix/* PR>.
  These dependencies must reach at least an open feat/* or fix/* PR before <STORY-KEY> starts.
  Next step: implement <blocker-key> first (or remove the Jira "Blocks" link if stale).
  ```
  This gate enforces the Jira dependency graph (kept in the Epic PRD's "Story Dependency Graph" section) — never implement a story ahead of the work it depends on.

## Step 2 — Derive the task list (from the plan doc, or — on the lightweight path — from the story)

**Full path (plan doc exists, `LIGHTWEIGHT` unset/false):**

1. Read `docs/superpowers/plans/<STORY-KEY>.md`.
2. Group tasks by agent tag: `[database-administrator]`, `[platform-engineer]`,
   `[ai-enablement-engineer]`, `[sync-engineer]`, `[web-engineer]`, `[mobile-engineer]`.
3. Cross-reference Active agents in project-context — drop Standby phases with no tasks.
4. Note any "grounding corrections" / "open items" the plan flagged — pass them verbatim into
   the relevant domain-agent prompt so the implementer honors them.

**Lightweight path (`LIGHTWEIGHT=true`, no plan doc):** there is no plan file to read — derive the
task list **inline from the Jira story**:

1. Fetch the story (summary + description + acceptance criteria) via
   `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` with `<KEY>=<STORY-KEY>`.
2. Turn it into an ordered, agent-tagged task list the same way `tech-lead` would: map each piece of
   work to the **Active** domain agent that owns its files (per project-context), in the standard
   dependency order (database-administrator → platform-engineer → ai-enablement-engineer →
   sync-engineer → web-engineer → mobile-engineer). Keep it proportional — a lightweight story is
   small, usually one or two domain agents and a handful of tasks.
3. Treat the **acceptance criteria as the completion contract** — pass them verbatim into each
   domain-agent prompt (there is no plan doc to carry them).

Either way, Step 3+ (the phase ladder) is identical.

## Step 2.5 — Detect child sub-tasks (drives per-sub-task commit sequencing)

Before branching, enumerate the story's child sub-tasks using the **"Fetching sub-tasks"**
subsection of `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` (JQL
`parent = <STORY-KEY> AND issuetype in subTaskIssueTypes() ORDER BY created ASC`,
`--fields "key,summary"`). That subsection is the source of truth — **do not re-document the probe.**

Define:
- `SUBTASKS` — the ordered list of `{ key, summary }` exactly as the probe returns it
  (`ORDER BY created ASC`; **never re-sort** by key or summary — fetch order *is* implementation order).
- `subtaskCount` — `SUBTASKS.length`.

Branch on the count:
- **`subtaskCount === 0`** → **no-regression path**: skip ALL sub-task sequencing. Steps 3–7 run
  exactly as they do today — one full-story implementation pass per phase, normal commit cadence,
  normal PR. An empty probe result is **not** an error.
- **`subtaskCount > 0`** → drive the per-sub-task commit sequencing in Step 4 and the sub-task
  enumeration in the Step 7 PR body.
- **Probe failure** (a real auth/DNS/malformed-JQL error, not an empty result) → **STOP before
  branching**, consistent with the `acli`-failure rule. Do not create a branch or dispatch agents.

Branch creation (Step 3) stays **once per story** regardless of `subtaskCount` — sub-tasks are
**never** given their own branches.

## Defect variant — `WORK_KIND=defect` drives the ladder via `systematic-debugging`

**Activation keys off `WORK_KIND=defect`, NOT `TRIAGE=lightweight`.** A lightweight *feature*
(`LIGHTWEIGHT=true`, `WORK_KIND=feature`) keeps the **normal feature ladder** below and is never
misrouted into debugging. When `WORK_KIND=defect`, the `systematic-debugging` skill becomes the
**impl driver** for the work Steps 2 and 4 do on the feature path — the rest of the ladder is
unchanged:

| Playbook step | Feature path (default) | Defect path (`WORK_KIND=defect`) |
| ------------- | ---------------------- | -------------------------------- |
| Step 2 (derive tasks) | derive agent-tagged task list from plan/story | **replaced** by systematic-debugging **phase 1 (reproduce)** + **phase 2 (root-cause/isolate)** — these *discover* the work; there is no plan doc and no pre-derived task list |
| Step 3 (branch) | `feat/<STORY-KEY>` | `fix/<STORY-KEY>` (`BRANCH_PREFIX`) — same structure, defect prefix |
| Step 4 (domain dispatch) | dispatch agents to write feature code | **replaced** by systematic-debugging **phase 3 (failing regression test)** + **phase 4 (fix + verify)**, where phase-3/4 *code-writing* is performed by **dispatching the same Active domain agents** (the skill orchestrates; the owning domain agent writes the test and the fix) |
| Step 5 (push/verify) | per-phase push + silent-failure STOP | **unchanged** — applied after each debugging-phase domain-agent commit |
| Step 6 (QA loop) | QA Engineer playbook inline | **unchanged in structure**; QA Step-7 verification is re-pointed to the defect regression-evidence contract (see `qa-engineer-playbook.md`) |
| Step 7 (PR) | `feat/<STORY-KEY>` PR, `feat` type | `fix/<STORY-KEY>` PR, `fix` type |

So debugging replaces the **"decide what to do + write the code" middle of the ladder (Steps 2+4)**;
branch (3), push/verify (5), QA (6), and PR (7) remain. Phase 4's fix is **not** the skill writing
code directly — it dispatches the owning domain agent exactly as Step 4 would, preserving the
multi-agent quality bar and the `isolation: "worktree"` + commit-not-push contract.

### The 4 phases mapped onto dispatch + verify

1. **Phase 1 — reproduce.** YOU (the top-level Principal Engineer session) reproduce the bug:
   establish the failing condition from the Jira Bug's **Steps to Reproduce / Actual Result**. No
   domain agent yet. **If reproduction is impossible → STOP / `blocked`** — do not guess a fix.
2. **Phase 2 — root-cause / isolate.** Identify the owning file(s)/domain. This determines which
   Active domain agent owns phases 3–4 for each affected slice.
3. **Phase 3 — add a failing regression test.** Dispatch the owning domain agent (`isolation:
   "worktree"`, **commit not push**) to add a test that **FAILS** against current `develop` behaviour
   and pins the bug.
4. **Phase 4 — fix + verify.** Dispatch the owning domain agent to implement the fix so the phase-3
   test now **PASSES**, then run the project quality gate (`typecheck` + `test`). Multiple affected
   domains run **sequentially in the normal dependency order** (database-administrator →
   platform-engineer → ai-enablement-engineer → sync-engineer → web-engineer → mobile-engineer), one
   agent at a time, each on the single `fix/<STORY-KEY>` branch.

Per-phase **Step-5 push/verify** runs after each domain-agent commit, exactly as on the feature path.
The phase-3 commit (test added, fix not yet applied) and HEAD (fix applied) are the QA Step-7
before/after evidence points (see `qa-engineer-playbook.md` §defect verification). Confirm the
`systematic-debugging` skill is invocable (Step 0) before phase 1.

> On the defect path **skip Step 2's task-derivation** (debugging phases 1–2 discover the work
> instead) and **replace Step 4's feature dispatch** with the phase-3/4 dispatch above. Steps 0, 1,
> 2.5, 3, 5, 6, 7, 8 run as written (Step 1's plan-file STOP is already relaxed by `LIGHTWEIGHT=true`,
> which the defect path always carries since a Bug triages lightweight).

## Step 3 — Create the implementation branch (YOU do this)

```bash
git checkout -b <BRANCH_PREFIX>/<STORY-KEY> origin/develop 2>/dev/null \
  || git checkout <BRANCH_PREFIX>/<STORY-KEY>
git push -u origin <BRANCH_PREFIX>/<STORY-KEY>
```

One branch per story — even when `subtaskCount > 0`, you create `<BRANCH_PREFIX>/<STORY-KEY>` exactly once
here; the sub-task loop in Step 4 is commit-only (no per-sub-task `git checkout -b`). Domain agents
never create branches or PRs. PR is opened only in Step 7, after QA returns `clean`.

## Step 4 — Dispatch domain agents (NON-NEGOTIABLE order, one at a time)

```
Phase 1 — [database-administrator]  schema + entities + migrations (ALWAYS FIRST; skip if Standby/no tasks)
Phase 2 — [platform-engineer]       backend infra + handlers + config
Phase 3 — [ai-enablement-engineer]  plugins/**, skills/**, AI-config surface (only if plan has tasks)
Phase 4 — [sync-engineer]           offline-sync rules + transactions (only if plan has tasks)
Phase 5 — [web-engineer]            web pages/components (only if plan has tasks)
Phase 6 — [mobile-engineer]         mobile screens (only if plan has tasks)
```

- Sequential only — never two domain agents at once.
- Each phase verified complete before the next is dispatched.

### Sub-task commit sequencing (only when `subtaskCount > 0`, from Step 2.5)

Sub-task sequencing happens **within** each domain phase — it does not reorder or replace the
phase ladder. When the story has sub-tasks, the domain agent for a phase implements that phase's
slice **one sub-task at a time, in `SUBTASKS` (fetch) order**, landing **a commit per sub-task that
touches this phase** (the "commit per sub-task" rule is scoped to the current phase — a sub-task
with no work in this phase produces no commit here; see the third bullet):

- Iterate `SUBTASKS` top-to-bottom (`ORDER BY created ASC`); **do not re-sort**.
- For each sub-task **whose work touches the current phase's domain**, make **≥1 commit** on the
  single `<BRANCH_PREFIX>/<STORY-KEY>` branch, with a conventional-commit message that **embeds the sub-task
  key**, e.g. `<type>(<scope>): [<SUBTASK-KEY>] <sub-task summary>` where `<type>` is **`fix` on the
  defect path (`WORK_KIND=defect`), `feat` on the feature path** (scope from the changed directory
  per the `conventional-commit` skill). Across the whole run every sub-task lands **≥1 commit** —
  in whichever phase(s) own its files — but within any single phase only the sub-tasks that phase
  touches get a commit.
- A sub-task whose work does not touch the current phase's domain contributes **no commit in that
  phase** — it lands its commits in whichever phase(s) own its files. Sequencing is within the
  ladder; it never breaks it.
- **No branch per sub-task** — every commit lands on the one `<BRANCH_PREFIX>/<STORY-KEY>` branch (Step 3).
- **Sequential only** — one sub-task at a time; no parallel sub-task work.
- **No Jira status transitions** on sub-tasks — `/impl` does not move sub-task status.

When `subtaskCount === 0`, ignore this subsection entirely: each phase is a single full-story pass
with the normal commit cadence (today's behaviour, unchanged).

Dispatch with the `Agent` tool, **`isolation: "worktree"`** (domain agents write code, they
need isolation):

```
Agent({
  subagent_type: "<agent-name>",
  isolation: "worktree",
  prompt: "<see prompt contract>"
})
```

### Domain-agent prompt contract (agent starts cold — include ALL of this)

1. Story key, e.g. `<STORY-KEY>`.
2. The full phase section from the plan, verbatim.
3. Relevant spec/plan context — entity names, field types, route paths, class/interface names,
   secret keys, SSM helper names — plus any plan "grounding corrections" verbatim.
4. "Branch `<BRANCH_PREFIX>/<STORY-KEY>` already exists on remote and is checked out. Do NOT create a new
   branch. Check it out, do your work, and commit."
5. "Do NOT create a PR — the orchestrator opens one after all phases and review are clean."
6. "Commit your changes (use the `conventional-commit` skill; scope from the directory
   name; **commit type `fix` on the defect path (`WORK_KIND=defect`), `feat` otherwise** — the
   orchestrator tells you which). Do NOT push — the orchestrator handles pushes."
   - **When the story has sub-tasks** (`subtaskCount > 0`): you are given the ordered `SUBTASKS`
     list. Implement your phase's slice **one sub-task at a time, in that order**, and make **a
     separate commit per sub-task** whose message embeds the sub-task key —
     `<type>(<scope>): [<SUBTASK-KEY>] <sub-task summary>` (`<type>` = `fix` for a defect / `feat` for
     a feature — the orchestrator tells you which). All commits go on the already-checked-out
     `<BRANCH_PREFIX>/<STORY-KEY>` branch (no new branch, no push). A sub-task with no work in your domain
     gets no commit in your phase — it is implemented in whichever phase owns its files, not
     dropped. When `subtaskCount === 0`, commit once for the phase as normal.
7. "Append non-obvious learnings to `.claude/memories/agents/<your-name>.md` and stage it with
   your commit (per `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`)."
8. "Use the package manager and infra stage flag from project-context (Tooling) on every infra CLI command."
9. "Return exactly:\n  Status: complete|blocked\n  Note: <one line if blocked>\n  Summary: <one line — files changed, key entities/handlers touched>"

Never send just a task title.

## Step 5 — Phase completion verification (after EACH phase)

```bash
git log <BRANCH_PREFIX>/<STORY-KEY> --oneline -5      # local HEAD must have advanced
git push origin <BRANCH_PREFIX>/<STORY-KEY>           # YOU push
git fetch origin <BRANCH_PREFIX>/<STORY-KEY>
```

- No new commits since pre-dispatch HEAD → agent failed silently. **STOP**, report. (With
  `subtaskCount > 0` a phase is expected to advance HEAD by **one commit per sub-task it touched**,
  not a single commit; "zero new commits" remains the silent-failure STOP condition.)
- Push fails (conflict/auth) → **STOP**, report.
- Agent returned `Status: blocked` → **STOP** immediately:
  ```
  BLOCKED at Phase N (<agent-name>).
  Reason: <Note>
  Next step: <what user must do>
  Remaining phases NOT dispatched.
  ```
  Do not fix the blocker yourself. Do not proceed.

Extract only `Status` / `Note` / `Summary` from each agent return; discard the rest.

## Step 6 — Hand off to the QA Engineer (inline)

The post-implementation code-quality loop is owned by the **QA Engineer**, not by you. Do NOT
run the review, fix, learn, gate, or verification steps here — **execute
`${CLAUDE_PLUGIN_ROOT}/refs/qa-engineer-playbook.md` inline**, in this same top-level session (the QA loop
must dispatch the `agent-skills:code-reviewer` subagent and domain fix agents, which needs the
`Agent` tool — it cannot be a subagent). Hand it:

- `<STORY-KEY>`
- `BASE_SHA` (captured in Step 1, before branching — the review-range start)
- The pushed `<BRANCH_PREFIX>/<STORY-KEY>` branch
- The Jira story summary + acceptance criteria (fetched by the caller)
- `WORK_KIND` (`defect` | `feature`) — re-points QA's Step-7 verification: on `defect`, QA requires
  the systematic-debugging regression-evidence contract (failing-before/passing-after test) instead
  of the plan-task checklist (see `qa-engineer-playbook.md`).

The QA playbook runs: request review → triage → fix loop (dispatching domain agents) →
re-review until clean → write learnings to memory → quality gate (the quality-gate commands from `.claude/project/project-context.md`)
→ AC + plan verification, and returns a verdict block:

```
## QA verdict: <STORY-KEY>
Status: clean | blocked
...
```

- `Status: blocked` → **STOP**. Surface the QA `Blocked reason` to the user exactly. Do NOT
  create the PR. Do NOT improvise around it.
- `Status: clean` → proceed to Step 7. QA has already written learnings, run the gate (output
  pasted), and confirmed every AC is evidenced — do not repeat that work; carry QA's verdict
  fields into your final report.

## Step 7 — Create the PR (only after QA returns `clean`)

Only after Step 6 returns `Status: clean`:

The PR **title always keeps the parent `<STORY-KEY>`** (never a sub-task key), and the PR opens from
the `<BRANCH_PREFIX>/<STORY-KEY>` head (`fix/` on a defect, `feat/` on a feature). Where the repo's
PR-title convention embeds a conventional-commit type, use `fix` on the defect path / `feat`
otherwise (matching the commit type from Step 4). When `subtaskCount > 0`, the PR **body lists every
sub-task key** from `SUBTASKS` (the parent PR enumerates the sequenced work); when
`subtaskCount === 0`, the body has no sub-tasks section (unchanged from today). Write the body to a
file first when it includes the sub-task list, then pass it by reference (`--body-file`):

```bash
# subtaskCount === 0 — inline short body (today's behaviour):
PR_URL=$(gh pr create \
  --title "[<STORY-KEY>] <story summary>" \
  --body "Implementation for <STORY-KEY>. All phases complete, review clean, quality gate passed." \
  --base develop \
  --head <BRANCH_PREFIX>/<STORY-KEY>)

# subtaskCount > 0 — write the enumerated body to the session temp dir, then pass by reference.
# Use the session-scoped temp dir (tmp-dir.sh) so session-complete.sh cleans it up — never a bare
# ./.tmp path or /tmp:
#   dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)   # session-scoped ./.tmp/<key>
#   write "$dir/pr-body.md":
#     Implementation for <STORY-KEY>. All phases complete, review clean, quality gate passed.
#
#     Sub-tasks (implemented in fetch order, one commit per sub-task):
#     - <SUBTASK-KEY> — <summary>
#     - <SUBTASK-KEY> — <summary>
#   PR_URL=$(gh pr create --title "[<STORY-KEY>] <story summary>" \
#     --body-file "$dir/pr-body.md" --base develop --head <BRANCH_PREFIX>/<STORY-KEY>)
gh pr ready "$PR_URL"
# Extra review layer (independent of the QA Engineer's Claude review loop in Step 6): request a
# Copilot code review on the new PR. Best-effort — NEVER let it fail PR creation. Needs gh >= 2.88.0 + Copilot code review
# enabled on the plan; if unavailable, the PR is already created and the pipeline continues.
gh pr edit "$PR_URL" --add-reviewer "@copilot" || echo "warn: @copilot reviewer not assigned (gh<2.88.0 or Copilot review unavailable) — PR created regardless"
```

Capture `PR_URL` (full `https://github.com/...`) for the caller (`/impl` posts it to Jira).

## Step 8 — Final report (to the caller / user)

Carry the QA verdict fields (Step 6) into the report — do not re-derive them.

```
## <Feature|Fix>: <name>  (Branch: <BRANCH_PREFIX>/<STORY-KEY>)   # "Fix" on the defect path, "Feature" otherwise
### Phases: <agents that ran + one-line summaries>
### QA: rounds <N>; fixed <Critical/Important list>; minor noted <list>; ACs <met — all N evidenced>
### Quality gate: typecheck pass | tests pass   (QA evidence)
### PR: <PR_URL>
### Status: all phases complete, QA verdict clean, gate passed, PR ready.
```

## Constraints

- Never start a story whose Jira blockers lack a `feat/*` or `fix/*` PR — the Step 1 dependency gate STOPs and rejects (no branch, no agents).
- Never skip the dependency order; never run two domain agents at once.
- YOU create the branch and push; domain agents only commit.
- The code-quality loop (review/fix/learn/gate/AC-verify) is owned by the QA Engineer (Step 6) — run it inline, do not duplicate it here.
- PR opened by YOU only after the QA Engineer returns `Status: clean` — never before.
- Any agent `blocked`, or a QA `Status: blocked` → stop, report immediately, do not create the PR.
- Never implement feature code yourself — coordinate only.
- Never dispatch a `principal-engineer` (or `qa-engineer`) subagent — run both playbooks inline.
