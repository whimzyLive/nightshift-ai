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
   `[ai-enablement-engineer]`, `[sync-engineer]`, `[web-engineer]`, `[mobile-engineer]`
   (`[ai-enablement-engineer]` is dependency-free — it may be dispatched at any point in the ladder,
   but still runs alone, one domain agent at a time, like every other phase — see Step 4).
3. Cross-reference Active agents in project-context — drop Standby phases with no tasks.
4. Note any "grounding corrections" / "open items" the plan flagged — pass them verbatim into
   the relevant domain-agent prompt so the implementer honors them.

**Lightweight path (`LIGHTWEIGHT=true`, no plan doc):** there is no plan file to read — derive the
task list **inline from the Jira story**:

1. Fetch the story (summary + description + acceptance criteria) via
   `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` with `<KEY>=<STORY-KEY>`.
2. Turn it into an ordered, agent-tagged task list the same way `tech-lead` would: map each piece of
   work to the **Active** domain agent that owns its files (per project-context), in the standard
   dependency order (database-administrator → platform-engineer → sync-engineer → web-engineer →
   mobile-engineer); `ai-enablement-engineer` (if applicable) is dependency-free and may be
   dispatched at any point in that order — it consumes no artifacts from other domain agents and
   nothing consumes its, though it still runs alone, one domain agent at a time, like every other
   phase. Keep it proportional — a lightweight story is small, usually one or two domain agents and
   a handful of tasks.
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
  (`ORDER BY created ASC`; **never re-sort** by key or summary — fetch order _is_ implementation order).
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

**Activation keys off `WORK_KIND=defect`, NOT `TRIAGE=lightweight`.** A lightweight _feature_
(`LIGHTWEIGHT=true`, `WORK_KIND=feature`) keeps the **normal feature ladder** below and is never
misrouted into debugging. When `WORK_KIND=defect`, the `systematic-debugging` skill becomes the
**impl driver** for the work Steps 2 and 4 do on the feature path — the rest of the ladder is
unchanged:

| Playbook step            | Feature path (default)                        | Defect path (`WORK_KIND=defect`)                                                                                                                                                                                                                                                    |
| ------------------------ | --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Step 2 (derive tasks)    | derive agent-tagged task list from plan/story | **replaced** by systematic-debugging **phase 1 (reproduce)** + **phase 2 (root-cause/isolate)** — these _discover_ the work; there is no plan doc and no pre-derived task list                                                                                                      |
| Step 3 (branch)          | `feat/<STORY-KEY>`                            | `fix/<STORY-KEY>` (`BRANCH_PREFIX`) — same structure, defect prefix                                                                                                                                                                                                                 |
| Step 4 (domain dispatch) | dispatch agents to write feature code         | **replaced** by systematic-debugging **phase 3 (failing regression test)** + **phase 4 (fix + verify)**, where phase-3/4 _code-writing_ is performed by **dispatching the same Active domain agents** (the skill orchestrates; the owning domain agent writes the test and the fix) |
| Step 5 (push/verify)     | per-phase push + silent-failure STOP          | **unchanged** — applied after each debugging-phase domain-agent commit                                                                                                                                                                                                              |
| Step 6 (QA loop)         | QA Engineer playbook inline                   | **unchanged in structure**; QA Step-7 verification is re-pointed to the defect regression-evidence contract (see `qa-engineer-playbook.md`)                                                                                                                                         |
| Step 7 (PR)              | `feat/<STORY-KEY>` PR, `feat` type            | `fix/<STORY-KEY>` PR, `fix` type                                                                                                                                                                                                                                                    |

So debugging replaces the **"decide what to do + write the code" middle of the ladder (Steps 2+4)**;
branch (3), push/verify (5), QA (6), and PR (7) remain. Phase 4's fix is **not** the skill writing
code directly — it dispatches the owning domain agent exactly as Step 4 would, preserving the
multi-agent quality bar and the orchestrator-owned-worktree (`cd "$WORKTREE"`) + commit-not-push
contract.

### The 4 phases mapped onto dispatch + verify

1. **Phase 1 — reproduce.** YOU (the top-level Principal Engineer session) reproduce the bug:
   establish the failing condition from the Jira Bug's **Steps to Reproduce / Actual Result**. No
   domain agent yet. **If reproduction is impossible → STOP / `blocked`** — do not guess a fix.
2. **Phase 2 — root-cause / isolate.** Identify the owning file(s)/domain. This determines which
   Active domain agent owns phases 3–4 for each affected slice.
3. **Phase 3 — add a failing regression test.** Dispatch the owning domain agent (working directory
   `$WORKTREE` from Step 3, **commit not push**) to add a test that **FAILS** against current
   `<BASE-BRANCH>` behaviour and pins the bug.
4. **Phase 4 — fix + verify.** Dispatch the owning domain agent to implement the fix so the phase-3
   test now **PASSES**, then run the project quality gate (`typecheck` + `test`). Multiple affected
   domains run **sequentially in the normal dependency order** (database-administrator →
   platform-engineer → sync-engineer → web-engineer → mobile-engineer), one agent at a time, each on
   the single `fix/<STORY-KEY>` branch; `ai-enablement-engineer` (if affected) is dependency-free and
   may be dispatched at any point in that order — it still runs alone, like any other phase, when
   dispatched.

Per-phase **Step-5 push/verify** runs after each domain-agent commit, exactly as on the feature path.
The phase-3 commit (test added, fix not yet applied) and HEAD (fix applied) are the QA Step-7
before/after evidence points (see `qa-engineer-playbook.md` §defect verification). Confirm the
`systematic-debugging` skill is invocable (Step 0) before phase 1.

> On the defect path **skip Step 2's task-derivation** (debugging phases 1–2 discover the work
> instead) and **replace Step 4's feature dispatch** with the phase-3/4 dispatch above. Steps 0, 1,
> 2.5, 3, 5, 6, 7, 8 run as written (Step 1's plan-file STOP is already relaxed by `LIGHTWEIGHT=true`,
> which the defect path always carries since a Bug triages lightweight).

## Step 3 — Provision the story worktree and create the implementation branch (YOU do this)

The **primary checkout is NEVER switched to the story branch.** The branch is created **inside** a
dedicated per-story worktree, so provisioning can never deadlock on "branch already checked out
elsewhere". This single worktree is reused for every phase in Step 4, re-provisioned idempotently
before any later fix-round dispatch (QA loop, `/review-fix`, `/sdlc:loop`), and torn down after the
PR is raised (Step 7) — see `${CLAUDE_PLUGIN_ROOT}/scripts/worktree-setup.sh`.

```bash
setup_out=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree-setup.sh <STORY-KEY> <BRANCH_PREFIX>/<STORY-KEY> <BASE-BRANCH>) \
  || { echo "STOP: worktree-setup.sh failed — see stderr above; do not dispatch any domain agent"; exit 1; }
WORKTREE=$(printf '%s\n' "$setup_out" | grep '^WORKTREE=' | cut -d= -f2-)
NX_CACHE_DIRECTORY=$(printf '%s\n' "$setup_out" | grep '^NX_CACHE_DIRECTORY=' | cut -d= -f2-)
git -C "$WORKTREE" push -u origin <BRANCH_PREFIX>/<STORY-KEY>
```

A non-zero exit from `worktree-setup.sh` is a hard failure — **STOP** the impl phase and report;
never fall back to dispatching a writing agent into the primary checkout.

One branch per story — even when `subtaskCount > 0`, `worktree-setup.sh` creates `<BRANCH_PREFIX>/<STORY-KEY>`
exactly once here (its case 3 — neither the branch nor the worktree existed yet); the sub-task loop
in Step 4 is commit-only (no per-sub-task branch). Domain agents never create branches or PRs. PR is
opened only in Step 7, after QA returns `clean`.

## Step 4 — Dispatch domain agents (NON-NEGOTIABLE order, one at a time)

```
Phase 1 — [database-administrator]  schema + entities + migrations (ALWAYS FIRST; skip if Standby/no tasks)
Phase 2 — [platform-engineer]       backend infra + handlers + config
Phase 3 — [sync-engineer]           offline-sync rules + transactions (only if plan has tasks)
Phase 4 — [web-engineer]            web pages/components (only if plan has tasks)
Phase 5 — [mobile-engineer]         mobile screens (only if plan has tasks)

[ai-enablement-engineer]            plugins/**, skills/**, AI-config surface (only if plan has tasks)
                                     — dependency-free: may be dispatched at ANY point in the ladder
                                     above (first, between numbered phases, or last) — it consumes
                                     no artifacts from other domain agents and nothing consumes its.
```

- Sequential only — never two domain agents at once. This applies to `ai-enablement-engineer` too:
  it is dependency-free in **order** only, not in concurrency — when dispatched it still runs alone,
  like any other phase, preserving one-writer-at-a-time on the single story branch (git
  single-branch/worktree constraint, Step-5 HEAD-advance check).
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

Dispatch with the `Agent` tool. The harness's **`isolation: "worktree"` param is NOT set** — the
orchestrator now owns isolation via the single per-story worktree provisioned in Step 3:

```
Agent({
  subagent_type: "<agent-name>",
  prompt: "<see prompt contract>"
})
```

### Domain-agent prompt contract (agent starts cold — include ALL of this)

1. **Mandatory first instruction (verbatim, with the real captured `$WORKTREE` substituted):**
   "Your working directory for ALL work is `<WORKTREE>` — `cd` into it before any read, edit,
   build, test, or commit. Do NOT operate in the primary checkout."
2. **Cache instruction (verbatim, with the real captured `$NX_CACHE_DIRECTORY` substituted):**
   "Before running any `nx` command (build/test/quality gate), export
   `NX_CACHE_DIRECTORY=<abs path>` so tasks hit the shared warm cache."
3. Story key, e.g. `<STORY-KEY>`.
4. The full phase section from the plan, verbatim.
5. **Applicable override skills** — EITHER name the specific project skills to invoke (read them
   from the target agent's override, `.claude/project/agents/<agent-name>.md`, the override's skills
   section — whatever heading it uses, the section listing skills to invoke via the Skill tool)
   with "Invoke these via the Skill tool BEFORE starting Task 1: `<skill-a>, <skill-b>`", OR state
   explicitly "No project skills apply for this task." The prompt MUST state exactly one of these
   two so the agent knows whether `Skills loaded: none` is correct.
6. Relevant spec/plan context — entity names, field types, route paths, class/interface names,
   secret keys, SSM helper names — plus any plan "grounding corrections" verbatim.
7. "Branch `<BRANCH_PREFIX>/<STORY-KEY>` already exists on remote and is checked out in `<WORKTREE>`
   (the working directory named in item 1). Do NOT create a new branch. Do your work there and
   commit."
8. "Do NOT create a PR — the orchestrator opens one after all phases and review are clean."
9. "Commit your changes (use the `conventional-commit` skill; scope from the directory
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
10. "Append non-obvious learnings to `.claude/memories/agents/<your-name>.md` and stage it with
    your commit (per `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`)."
11. "Use the package manager and infra stage flag from project-context (Tooling) on every infra CLI command."
12. "Return exactly (per `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md` — 3 lines complete, 4 lines blocked):\n Status: complete|blocked\n Note: <one line if blocked, else omit>\n Summary: <one line — files changed, key entities/handlers touched>\n Skills loaded: <comma-separated override skill names | none>"

Never send just a task title.

## Step 5 — Phase completion verification (after EACH phase)

**Before dispatching the phase**, capture the primary checkout's state so a violation is machine-
detectable, not prose-only (spec §5). This is a **snapshot to diff against later, not an
assertion** — the primary may already be dirty (unrelated developer WIP) before this story's first
dispatch, and that pre-existing dirt is not itself a violation:

```bash
PRIMARY_HEAD=$(git -C "<primary-root>" rev-parse HEAD)
PRIMARY_CLEAN_BEFORE=$(git -C "<primary-root>" status --porcelain)   # snapshot as-is (may be non-empty)
```

If `PRIMARY_CLEAN_BEFORE` is non-empty the very first time you capture it for this story, that
means the primary checkout was already dirty before any dispatch — proceed anyway with a one-line
warning (`WARNING: primary checkout has pre-existing uncommitted changes unrelated to this story —
snapshotting and comparing, not blocking`); do not STOP on pre-existing dirt you didn't cause.

**After the agent returns**, run the worktree HEAD-advance/push checks against `$WORKTREE` (never
the primary checkout — the domain agent's commits live there):

```bash
git -C "$WORKTREE" log <BRANCH_PREFIX>/<STORY-KEY> --oneline -5      # local HEAD must have advanced
git -C "$WORKTREE" push origin <BRANCH_PREFIX>/<STORY-KEY>           # YOU push, from the worktree
git fetch origin <BRANCH_PREFIX>/<STORY-KEY>
```

Then assert the primary checkout matches its pre-dispatch snapshot exactly — HEAD identical AND
status output identical to `PRIMARY_CLEAN_BEFORE` (NOT asserted empty; a pre-dirty primary that
stays at the same dirt is a pass, only a _change_ from the captured snapshot is a violation):

```bash
[ "$(git -C "<primary-root>" rev-parse HEAD)" = "$PRIMARY_HEAD" ] \
  && [ "$(git -C "<primary-root>" status --porcelain)" = "$PRIMARY_CLEAN_BEFORE" ] \
  || echo "STOP: domain agent wrote to the primary checkout instead of \$WORKTREE"
```

If the primary checkout's HEAD moved, or its working tree no longer matches the pre-dispatch
snapshot → the agent ignored the cwd instruction (Step 4 prompt-contract item 1) and wrote to (or
committed in) the primary checkout instead of `$WORKTREE` — **fail the phase and STOP**, same shape
as the silent-failure STOP below.
This makes the isolation guarantee a hard, detectable failure instead of a silently-corrupted
primary checkout.

Also assert `$WORKTREE` itself is clean after the phase's commit — the shared, persistent
`$WORKTREE` carries forward between phases and fix rounds, so a returning agent's forgotten
uncommitted stray (e.g. a new source file never `git add`ed) would otherwise sit there silently
until a LATER agent's `git add`/commit sweeps it in as an unintended, unattributed change:

```bash
[ -z "$(git -C "$WORKTREE" status --porcelain)" ] \
  || echo "STOP: \$WORKTREE has stray uncommitted/untracked files after the phase commit — $(git -C "$WORKTREE" status --porcelain)"
```

A non-empty result → **fail the phase and STOP**, same shape as the silent-failure STOP, listing the
stray files.

- No new commits since pre-dispatch HEAD (on `$WORKTREE`) → agent failed silently. **STOP**, report. (With
  `subtaskCount > 0` a phase is expected to advance HEAD by **one commit per sub-task it touched**,
  not a single commit; "zero new commits" remains the silent-failure STOP condition. Exception: the
  Skills-loaded RETURN-CONTRACT redispatch below is explicitly exempt from this rule.)
- Push fails (conflict/auth) → **STOP**, report.
- Agent returned `Status: blocked` → **STOP** immediately:
  ```
  BLOCKED at Phase N (<agent-name>).
  Reason: <Note>
  Next step: <what user must do>
  Remaining phases NOT dispatched.
  ```
  Do not fix the blocker yourself. Do not proceed. This STOP is unconditional — a `Status: blocked`
  return never reaches the `Skills loaded` verification below, so it carries no skill-coverage
  obligation (`Skills loaded: none` on an early-abort blocked return is expected, not a failure).
- **Verify `Skills loaded` covers the named set — applies only to `Status: complete` returns.**
  Compare the returned `Skills loaded` value against the skills the dispatch prompt named (item 3
  of the prompt contract), mechanically:
  - Prompt **named skills** `S`: pass iff the line is present and **every** skill in `S` appears.
    Missing line, empty value, `none`, or any named skill absent → **failure**.
  - Prompt **declared no applicable skills**: pass iff the line is present and non-empty —
    `Skills loaded: none` passes, and so does a line listing extra skills the agent chose to load
    on its own initiative (the handoff forbids emitting `none` when a skill was actually loaded, so
    both honest forms are valid). Failure only on a missing or empty line.

  On failure → **STOP-and-redispatch that phase once**, scoped as a RETURN-CONTRACT redispatch: the
  phase's work is already committed, so the redispatch prompt tells the agent (a) the phase's code
  changes already landed, (b) invoke the named skills now, verify the already-committed work against
  them, fixing only if a skill mandates a change, and (c) re-emit a compliant return. Because the
  work may already conform, **zero new commits from this redispatch is an acceptable outcome** — it
  is exempt from the "no new commits → silent failure" STOP above; only judge it on whether the
  re-emitted `Skills loaded` line now passes. A persistent failure on the single redispatch →
  **STOP and report to the user** (same shape as the silent-failure STOP above).

Extract only `Status` / `Note` / `Summary` / `Skills loaded` from each agent return; discard the rest.

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

## Step 6.5 — Post-QA docs sync (on a clean QA verdict, before the PR)

Reached **only** after Step 6 returns `Status: clean` (a `Status: blocked` QA verdict already STOPped
the run at Step 6 — Step 6.5 never runs; AC5). The story branch `<BRANCH_PREFIX>/<STORY-KEY>` is
pushed and **unmerged**, and its `$WORKTREE` is still provisioned (teardown is Step 7), so the docs
commit lands on the branch **before** the PR opens — folding into the same impl PR (AC2). This wires
the existing `sync` in via its **inline post-QA dispatch variant**
(`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md` §25); the diff source is **story-branch-vs-base**
(§26), passed explicitly.

**Manifest gate (AC4).** Resolve `.claude/project/docs-manifest.md` checkout-independently
(`git show origin/<BASE-BRANCH>:.claude/project/docs-manifest.md`). If **absent** → **clean no-op**:
do not dispatch, no warning, no report line — the repo opted out of docs. Proceed to Step 7
unchanged. This is a no-op, **not** a failure.

**Primary-checkout guard — reuse Step 5's machine check verbatim.** Before dispatching, snapshot the
primary checkout (`PRIMARY_HEAD` + `PRIMARY_CLEAN_BEFORE`, exactly as Step 5). Dispatch the
`knowledge-engineer` post-QA variant, handing it — like every Step 4 / QA-Step-3 dispatch — the live
`$WORKTREE` (at `<BRANCH_PREFIX>/<STORY-KEY>`), `$NX_CACHE_DIRECTORY`, the story key, and the
story-branch-vs-base diff source (`origin/<BASE-BRANCH>...<BRANCH_PREFIX>/<STORY-KEY>`). The agent
**commits only** (no push, no PR); **you** push from `$WORKTREE` and re-run Step 5's assertions.

Classify the outcome into **exactly four** buckets (do not collapse them):

| Outcome at Step 6.5                                                                                                                                                                                                              | Class                         | Behaviour                                                                                                                                                                                                                                           |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.claude/project/docs-manifest.md` **absent**                                                                                                                                                                                    | **no-op (AC4)**               | No dispatch. Proceed to Step 7 unchanged. No warning, no report line.                                                                                                                                                                               |
| Manifest present; regen byte-identical **and** no `how-to` affected (change-gate, §6)                                                                                                                                            | **no-op**                     | Agent makes no commit (`git status --porcelain` empty on written paths). Proceed to Step 7. Step 8 report notes `Docs sync: no changes`. Not a failure.                                                                                             |
| Manifest present; **docs-content failure** — regen error, docs-commit push failure, or the agent returns `Status: blocked`                                                                                                       | **failure (loud, non-block)** | **WARN, do not block.** Emit a distinct `WARNING: post-QA docs sync failed …`. **Still proceed to Step 7 and open the impl PR** (without the docs commit). The Step 8 report carries a `Docs sync:` line naming the failure + the recovery pointer. |
| **Workspace-integrity failure** — the dispatch moved the **primary checkout's HEAD**, or its `git status --porcelain` no longer matches the pre-dispatch snapshot, or `$WORKTREE` is left with stray uncommitted/untracked files | **failure (hard STOP)**       | **STOP the run**, same shape as Step 5's guard. Do **not** open the impl PR while the primary checkout is corrupted, or while `$WORKTREE` carries an unattributable stray. Surface the exact violation.                                             |

**Why the split (state it inline so a later edit does not blanket-downgrade or blanket-STOP):**

- A **docs-content** miss is **recoverable by construction** — the code branch is untouched and
  `/sdlc:docs sync <STORY-KEY>` (now backed by the merged-commit source this story adds, §26)
  regenerates the docs after merge. Blocking a QA-clean, about-to-ship implementation PR over a docs
  regeneration hiccup would invert the story's value. Loud-but-non-blocking + a working recovery path
  is the balance.
- A **workspace-integrity** failure is **not** recoverable-by-construction — a mutated/dirty primary
  checkout or a stray commit on the wrong branch outlives this run and breaks the next branch
  operation / the next epic child. The recovery argument that justifies the docs-content WARN does
  **not** exist here, so it must not be stretched to cover it. The primary-checkout guard stays a
  **STOP**, identical to Step 5.

**`Status: blocked` from the post-QA `knowledge-engineer` dispatch is a docs-content WARNING here —
NOT a run STOP.** This is the **one** place an in-playbook agent `blocked` does not halt the run
(contrast Step 5 / Step 6, where `blocked` = STOP). A primary-checkout violation is detected by the
machine guard **independently of the agent's returned `Status`** and still STOPs.

Then proceed to Step 7 (unless a workspace-integrity STOP fired). The docs commit, when made, is the
last commit before the PR opens.

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

**Teardown the impl worktree** immediately after the PR is raised:

```bash
git worktree remove --force "$WORKTREE"
```

This satisfies AC-1 literally — the impl worktree does not sit idle after the PR. It does **not**
strand later review-fix rounds: any subsequent QA fix round, standalone `/review-fix`, or
`/sdlc:loop` entry re-provisions the same worktree idempotently (`worktree-setup.sh`, invariant 2)
before dispatching its next fix agent.

## Step 8 — Final report (to the caller / user)

Carry the QA verdict fields (Step 6) into the report — do not re-derive them. The `Docs sync:` line
reports Step 6.5's outcome: `no changes` / `committed` on the two no-op-or-success paths, the
`WARN … recover with /sdlc:docs sync <STORY-KEY>` wording on a docs-content failure, and
`skipped (no docs manifest)` when the manifest was absent.

```
## <Feature|Fix>: <name>  (Branch: <BRANCH_PREFIX>/<STORY-KEY>)   # "Fix" on the defect path, "Feature" otherwise
### Phases: <agents that ran + one-line summaries>
### QA: rounds <N>; fixed <Critical/Important list>; minor noted <list>; ACs <met — all N evidenced>
### Quality gate: typecheck pass | tests pass   (QA evidence)
### Docs sync: <no changes | committed on the branch | WARN: <failure> — recover with `/sdlc:docs sync <STORY-KEY>` after merge | skipped (no docs manifest)>
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
