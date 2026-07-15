# QA Engineer Playbook (post-implementation quality loop)

The code-quality lifecycle for a Jira story implementation. **This playbook is executed
INLINE by the top-level session** — it is invoked by the Principal Engineer playbook
(`${CLAUDE_PLUGIN_ROOT}/refs/principal-engineer-playbook.md`, Step 6) once all domain-agent
implementation phases are pushed to `<BRANCH_PREFIX>/<STORY-KEY>`. It is NOT dispatched as a subagent.

## Why inline (read this first)

Claude Code blocks subagent → subagent dispatch (nesting is one level deep). The QA loop's
whole job is to dispatch an `agent-skills:code-reviewer` subagent AND dispatch domain agents
to fix what the review finds — both need the `Agent` tool, which only works at the top level.
The Principal Engineer playbook already runs inline; when it reaches Step 6 it **continues
running these QA steps in the same top-level session**. Do NOT dispatch a `qa-engineer`
subagent — it would be unable to dispatch the reviewer or fixers and would return blocked.

## Role

You own the quality of what ships. After the code is written, you make sure it is:

- **Correct** — does what the plan/ACs require, no regressions.
- **Clean** — readable, follows project conventions, no dead/duplicated code.
- **Secure** — no injection, secret-leak, auth-bypass, or unsafe-input issues.
- **Not broken** — typecheck + tests green on the real pushed tree.
- **AC-complete** — every acceptance criterion the ticket was created for is met, with evidence.

You coordinate; you never write feature code yourself — domain agents do the fixing. You own
the review loop, the learnings memory, the quality gate, and the final AC/plan verification.
You return a single verdict (`clean` or `blocked`) to the Principal Engineer.

## Inputs (handed in by the Principal Engineer playbook)

- `<STORY-KEY>` — the Jira story key for this run
- `BASE_SHA` — the review-range start. Both caller forms are valid: `/impl`'s principal playbook
  captures `git rev-parse origin/develop` before branching; `/review` Story mode uses
  `git merge-base origin/develop origin/<BRANCH_PREFIX>/<STORY-KEY>`. They differ only if `develop` advanced
  after branching; merge-base is the more precise start.
- Branch `<BRANCH_PREFIX>/<STORY-KEY>` exists on origin with all implementation phases pushed
- Plan path: `docs/superpowers/plans/<STORY-KEY>.md`
- Jira story summary + acceptance criteria (from the story body the caller already fetched)
- `WORK_KIND` — `defect` | `feature`, handed in by the caller (default `feature` when absent).
  Supplied by: the Principal Engineer playbook (inline `/auto`/`/impl`) and `commands/review.md`
  (derived from the resolved branch prefix). **`BRANCH_PREFIX` is derived from it** — `fix` on
  `defect`, `feat` on `feature` — so every `<BRANCH_PREFIX>/<STORY-KEY>` reference below resolves the
  right branch (no Jira fetch). `WORK_KIND=defect` also re-points the Step-7 verification to the
  defect regression-evidence contract (see Step 7). Without `WORK_KIND`, the defect contract cannot
  fire — a defect would silently pass the feature AC checklist.
  > **The `/review-fix` entry path does NOT supply `WORK_KIND`** (it defaults to `feature`). That is
  > intentional: `/review-fix` gates its AC/plan verification on **plan-doc existence**, not on
  > `WORK_KIND` (see `commands/review-fix.md`) — a defect has no plan doc, so that verification is
  > correctly skipped. The defect regression-evidence contract is enforced on the `/auto`/`/impl` and
  > `/review` paths, which do supply `WORK_KIND`.

## Modes

The loop runs in one of two modes. The caller picks the mode; the steps below are written for
**Story mode** (the default, used by `/impl` and `/review <STORY-KEY>`). **Diff mode** is the
lean ad-hoc variant used by `/review` with no story key — it reviews the current change set with
no Jira ticket, plan, or PR.

|                                         | Story mode                                                                    | Diff mode (ad-hoc, no story key)                                                                                                                                                                                                                     |
| --------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Trigger                                 | `<STORY-KEY>` provided                                                        | no story key — review the current diff                                                                                                                                                                                                               |
| Review target                           | commit range `BASE_SHA..origin/<BRANCH_PREFIX>/<STORY-KEY>`                   | **single-point working-tree diff** `git diff <BASE_SHA>` (committed-unmerged + staged + **uncommitted**) + untracked files, where `BASE_SHA = git merge-base origin/develop HEAD` — NOT a commit range (a commit range cannot see uncommitted edits) |
| Requirements given to reviewer (Step 1) | plan + acceptance criteria                                                    | the change's own intent (commit subjects + changed-file summary) — there are no ACs                                                                                                                                                                  |
| Fix commits (Step 3)                    | committed by domain agent, **pushed** by you to `<BRANCH_PREFIX>/<STORY-KEY>` | applied in the **working tree**, committed only if the change set was already committed; **never pushed** — leave for the user                                                                                                                       |
| Learnings memory (Step 5)               | required                                                                      | **skip** — no story to key the entry to                                                                                                                                                                                                              |
| AC + plan verification (Step 7)         | required                                                                      | **skip the AC/plan checklist**; instead confirm every review finding is resolved and the gate is green                                                                                                                                               |
| Verdict (Step 8)                        | full block incl. AC + learnings lines                                         | drop the `AC check` and `Learnings` lines; add `Fixes: applied in working tree (not pushed)`                                                                                                                                                         |

Everything else (request review → triage → fix → re-review → quality gate → return verdict) is
identical. In Diff mode, wherever a step says `<BRANCH_PREFIX>/<STORY-KEY>`, operate on the current branch /
working tree instead, and never push.

## Project constants

All project constants — base branch, quality gate, package manager, infra stage flag, active
agents — live in `.claude/project/project-context.md`. Read it first. This playbook references
them as tokens (`<BASE-BRANCH>`, `<BRANCH_PREFIX>/<STORY-KEY>`) and never hardcodes values.

Skip phases for agents marked **Standby** in project-context.

---

## Step 0 — Required skills

**Nesting self-guard (first):** confirm the `Agent` tool is available to you. If it is not, you
were dispatched as a subagent — STOP and return the BLOCKED message from the qa-engineer profile.
Do not review, fix, or improvise the loop yourself.

Invoke, in order, before reviewing anything:

1. `requesting-code-review`
2. `receiving-code-review`
3. `verification-before-completion`

## Step 1 — Request review

Resolve the review target — this differs by mode, because the `requesting-code-review` skill
diffs a **committed** `BASE_SHA..HEAD_SHA` range and so cannot see uncommitted edits:

**Story mode** — everything is already committed + pushed:

```bash
git fetch origin <BRANCH_PREFIX>/<STORY-KEY>
HEAD_SHA=$(git rev-parse origin/<BRANCH_PREFIX>/<STORY-KEY>)
```

Pass `BASE_SHA` (handed in) and `HEAD_SHA` to the reviewer as a `BASE_SHA..HEAD_SHA` range.

**Diff mode** — the change set may be uncommitted, so do NOT use a commit range. Instead tell
the reviewer to read the working-tree diff directly against `BASE_SHA`, which captures
committed-but-unmerged **and** staged **and** unstaged changes in one shot (this is the same
single-point `git diff <BASE_SHA>` the empty-diff guard uses, so guard and review agree):

```
git --no-pager diff <BASE_SHA>            # tracked changes (committed-unmerged + staged + unstaged)
git status --porcelain                    # surface any untracked new files to read in full
```

Dispatch an `agent-skills:code-reviewer` subagent following the `requesting-code-review`
skill pattern. The prompt MUST include:

- `DESCRIPTION`: Story mode — "Implementation of <STORY-KEY> — <story summary>"; Diff mode —
  the change's own intent (commit subjects + changed-file summary).
- `PLAN_OR_REQUIREMENTS`: Story mode — the story's **acceptance criteria verbatim** (the reviewer
  must check the code against the ACs, not just internal consistency), **plus** the full content of
  `docs/superpowers/plans/<STORY-KEY>.md` **when that file exists** (the full path). On the
  **lightweight** path there is no plan doc — use the Jira story **description + acceptance criteria**
  as the requirement source (the ACs are the contract). Diff mode — there are no ACs/plan; the
  requirement is the change's stated intent.
- The review target: Story mode — `BASE_SHA..HEAD_SHA`; Diff mode — the `git diff <BASE_SHA>`
  working-tree diff plus any untracked files (NOT a commit range).
- Explicit instruction to review across all five axes: **correctness, readability,
  architecture, security, performance** — and (Story mode) to flag any AC that is not demonstrably
  met and any regression risk to existing behavior.

Dispatch with `isolation: "worktree"` is NOT needed — the reviewer reads, it does not write.

### Alternative entry — external review feedback (`/review-fix`)

When findings come from an existing **GitHub PR or commit** (Copilot or human reviewers) rather
than a fresh code-reviewer pass, SKIP the dispatch above. Instead build the finding list from the
fetched comments:

- The caller (`/review-fix`) has fetched the feedback into files under the session temp dir
  (`dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)`): `"$dir/review-fix-summary.json"` = PR
  **body** + general/issue comments + review-summary bodies; `"$dir/review-fix-inline.json"` =
  **unresolved** inline review comments. Read BOTH. The only
  exclusion is inline threads explicitly marked _Resolved_ (filtered at fetch via GraphQL
  `reviewThreads.isResolved`, since a resolved comment is already addressed). The PR body and all
  generic comments have no resolved state and are ALWAYS included — they carry intent the
  line-anchored notes assume.
- Each inline comment becomes one candidate finding; treat the PR body + general comments as
  context AND as potential candidate requests in their own right. Keep each comment's file/line
  anchor, author, AND its numeric `id` (databaseId) — the `id` is required to reply on and resolve
  that exact thread in the close-out step. (Do NOT re-triage already-resolved threads — they were
  excluded at fetch.)
- Treat these EXACTLY as if a reviewer had produced them, then proceed to Step 2 triage — which is
  where you decide which are real (`receiving-code-review`). Record a decision ledger row per
  comment: `{id, path:line, decision: accepted|rejected, justification}`.

This mode operates on the **PR head branch** (or the commit's branch): fix commits in Step 3 are
committed AND **pushed** to that branch, so the PR updates and the original reviewers see the
resolution. The re-review in Step 4 is a fresh `agent-skills:code-reviewer` pass over the
**applied fix commits** (`BASE_SHA` = pre-fix HEAD, `HEAD_SHA` = post-fix HEAD) to confirm each
accepted comment is correctly resolved and nothing regressed.

**Close out the PR threads (after fixes are pushed + the gate is green — `/review-fix` only).**
Post each decision back on the PR so the reviewer sees only what they still need to look at, every
item carrying a justification. For each triaged inline comment, write the reply to a file (never
inline JSON) and call the helper:

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)   # session-scoped ./.tmp/<key>
bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-resolve-comment.sh <PR> <comment-id> accepted "$dir/reply-<id>.md"   # replies + RESOLVES the thread
bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-resolve-comment.sh <PR> <comment-id> rejected "$dir/reply-<id>.md"   # replies, leaves thread OPEN
```

- **Accepted** → reply names why it was valid + the fix commit, then the thread is RESOLVED (drops
  off the reviewer's open list).
- **Rejected** → reply explains why it's wrong/stale/out-of-scope in this app; thread stays OPEN.
- Review-summary bodies / top-level issue comments are not resolvable threads → post ONE
  summarising PR issue comment (`gh pr comment`) listing those decisions instead.
- Commit-SHA target → reply on the commit comment; nothing to resolve.
- Best-effort: a reply/resolve failure must NOT fail the run (fixes are already pushed) — log + continue.

## Step 2 — Triage feedback (receiving-code-review)

Apply the `receiving-code-review` skill. For each finding, classify by **severity** and
**domain**. Do not perform agreement — verify each finding is technically real before queuing a
fix; push back (in the final report) on any finding that is wrong or out of scope, with reasons.

For external feedback (`/review-fix`): keep only comments that are **true in the context of this
application** — discard ones that are wrong, stale (already addressed), based on a misreading, or
out of scope, and record the one-line rationale for each discard so the caller can reply on the
PR. Accepted comments flow into the Step 3 fix loop; discarded ones go in the return report only.

**Severity:**

- **Critical / Important** — must fix before the PR is created.
- **Minor / nit** — list in the return report, do not block.
- **AC gap** — treat as Critical regardless of how the reviewer framed it; the ticket exists to
  satisfy its ACs.
- **Security** — treat as Critical unless demonstrably non-exploitable; say why if downgraded.

**Domain mapping (file path → owning agent — derive from project-context Workspace Structure):**

See the workspace→agent table in `.claude/project/project-context.md`.

## Step 3 — Fix loop

**Idempotent re-provision, BEFORE dispatching any fix agent.** This loop can be entered in a fresh
session after Step-7 impl teardown or a GC sweep — the worktree may not exist. Re-provision it
(a no-op when it already exists and is current) and capture the two lines for every dispatch below:

```bash
setup_out=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree-setup.sh <STORY-KEY> <BRANCH_PREFIX>/<STORY-KEY> <BASE-BRANCH>) \
  || { echo "STOP: worktree-setup.sh failed — see stderr above; do not dispatch any fix agent"; exit 1; }
WORKTREE=$(printf '%s\n' "$setup_out" | grep '^WORKTREE=' | cut -d= -f2-)
NX_CACHE_DIRECTORY=$(printf '%s\n' "$setup_out" | grep '^NX_CACHE_DIRECTORY=' | cut -d= -f2-)
```

For each Critical / Important group (grouped by domain), dispatch the owning domain agent with the
`Agent` tool. The harness's `isolation: "worktree"` param is NOT set — the orchestrator owns
isolation via the `$WORKTREE` re-provisioned above. **Branch the dispatch mechanism on the `SDLC
agent reuse` token** (`.claude/project/project-context.md` Tooling):

- `disabled` → today's behaviour: dispatch a **fresh** `Agent({ subagent_type: "<agent-name>", ... })`
  for this fix round.
- `enabled` (shipped default) → **reuse** the same domain-agent instance that ran this domain's
  implementation phase, via `SendMessage` (relaying the resume as authorized same-task control —
  consistent with `scrum-master.md`'s resume-trust rule), avoiding re-paid frontmatter/skill
  injection. **Fall back to a fresh `Agent(...)` dispatch** whenever the reused instance is
  unavailable (session boundary, the instance already returned/terminated) — this is the explicit
  fallback, not an error. Accepted trade-off until NA-23 lands: a resumed instance re-pays
  frontmatter skill injection (harness bug #76337) — wasted tokens, not a correctness risk.

Either way, the prompt (fresh dispatch) or resume message (reused instance) MUST include:

1. **Mandatory first instruction (verbatim, with the real captured `$WORKTREE` substituted):**
   "Your working directory for ALL work is `<WORKTREE>` — `cd` into it before any read, edit,
   build, test, or commit. Do NOT operate in the primary checkout."
2. **Cache instruction (verbatim, with the real captured `$NX_CACHE_DIRECTORY` substituted):**
   "Before running any `nx` command (build/test/quality gate), export
   `NX_CACHE_DIRECTORY=<abs path>` so tasks hit the shared warm cache — this also covers your own
   quality-gate run in Step 6."
3. Story key.
4. The reviewer findings for that domain, **verbatim**.
5. **Applicable override skills** — EITHER name the target agent's applicable project skills
   (from its override `.claude/project/agents/<agent-name>.md`, the override's skills section —
   whatever heading it uses, the section listing skills to invoke via the Skill tool) with "Invoke
   these via the Skill tool BEFORE fixing: `<skill-a>, <skill-b>`", OR state explicitly "No project
   skills apply for this task." Exactly one of the two.
6. "Branch `<BRANCH_PREFIX>/<STORY-KEY>` already exists on remote and is checked out in `<WORKTREE>`
   (the working directory named in item 1). Fix ONLY these issues, and commit (use the
   `conventional-commit` skill). Do NOT push — the QA loop handles pushes."
7. "Append non-obvious learnings to `.claude/memories/agents/<your-name>.md` and stage it with
   your commit."
8. "Use the package manager and infra stage flag from project-context (Tooling) on every infra CLI command."
9. "Return exactly (per `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md` — 3 lines complete, 4 lines blocked):\n Status: complete|blocked\n Note: <one line if blocked, else omit>\n Summary: <one line — what changed>\n Skills loaded: <comma-separated override skill names | none>"

**Before dispatching**, capture the primary checkout's state (spec §5, same machine guard as
principal playbook Step 5) — a **snapshot to diff against later, not an assertion**; the primary
may already be dirty (unrelated developer WIP), and that pre-existing dirt is not itself a
violation:

```bash
PRIMARY_HEAD=$(git -C "<primary-root>" rev-parse HEAD)
PRIMARY_CLEAN_BEFORE=$(git -C "<primary-root>" status --porcelain)   # snapshot as-is (may be non-empty)
```

If `PRIMARY_CLEAN_BEFORE` is non-empty the first time you capture it in this run, proceed anyway
with a one-line warning (`WARNING: primary checkout has pre-existing uncommitted changes unrelated
to this story — snapshotting and comparing, not blocking`); do not return `blocked` on pre-existing
dirt you didn't cause.

After the agent returns, push and confirm from the worktree:

```bash
git -C "$WORKTREE" push origin <BRANCH_PREFIX>/<STORY-KEY>
git fetch origin <BRANCH_PREFIX>/<STORY-KEY>
git log origin/<BRANCH_PREFIX>/<STORY-KEY> --oneline -3
```

Then assert the primary checkout matches its pre-dispatch snapshot exactly — HEAD identical AND
status output identical to `PRIMARY_CLEAN_BEFORE` (NOT asserted empty; a pre-dirty primary that
stays at the same dirt is a pass, only a _change_ from the captured snapshot is a violation):

```bash
[ "$(git -C "<primary-root>" rev-parse HEAD)" = "$PRIMARY_HEAD" ] \
  && [ "$(git -C "<primary-root>" status --porcelain)" = "$PRIMARY_CLEAN_BEFORE" ] \
  || echo "BLOCKED: fix agent wrote to the primary checkout instead of \$WORKTREE"
```

If the primary checkout's HEAD moved, or its working tree no longer matches the pre-dispatch
snapshot → **return `blocked`** immediately with that reason (same detectable-failure shape as the
principal playbook's Step-5 guard) — do not attempt to fix or revert it yourself.

- No new commit since pre-dispatch HEAD (on `$WORKTREE`) → agent failed silently. **Return `blocked`**
  to the Principal Engineer with the reason.
- `Status: blocked` → **return `blocked`** immediately; do not attempt the fix yourself.
- **Verify `Skills loaded` covers the named set.** Same mechanical rule as principal playbook Step 5
  (source of truth — do not re-derive here); the QA-specific consequence differs: missing/failed →
  return `blocked` immediately, no redispatch. (Applies only to `Status: complete` returns, and
  extra skills the agent lists beyond the named set still pass, per Step 5.)

## Step 4 — Re-review

After all fixes are pushed, repeat Steps 1–3 until the reviewer returns **no Critical/Important
findings and no open AC gaps**. Minor issues: collect for the return report, do not loop.

## Step 5 — Write learnings to memory

After review rounds are clean, sync and record what was learned so future implementations avoid
the same mistakes — all of this happens in **`$WORKTREE`, never the primary checkout** (the
primary never checks out the story branch — see Step 3). Re-provision is idempotent and cheap
even when Step 3's fix loop never ran this pass (a first-pass-clean review skips Step 3 entirely,
so this is the first point `$WORKTREE` is guaranteed to exist):

```bash
setup_out=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree-setup.sh <STORY-KEY> <BRANCH_PREFIX>/<STORY-KEY> <BASE-BRANCH>) \
  || { echo "STOP: worktree-setup.sh failed — see stderr above"; exit 1; }
WORKTREE=$(printf '%s\n' "$setup_out" | grep '^WORKTREE=' | cut -d= -f2-)
NX_CACHE_DIRECTORY=$(printf '%s\n' "$setup_out" | grep '^NX_CACHE_DIRECTORY=' | cut -d= -f2-)
git -C "$WORKTREE" fetch origin <BRANCH_PREFIX>/<STORY-KEY> && git -C "$WORKTREE" merge --ff-only origin/<BRANCH_PREFIX>/<STORY-KEY>
DATE=$(date +%Y-%m-%d)
```

**1. Audit log** — append to `$WORKTREE/.claude/memories/reviews/patterns.md`, **unconditionally,
every round, regardless of any ADR-index match:**

```
## ${DATE} — Story <STORY-KEY>
**Issues found:** <Critical/Important + any AC/security gaps, or "none — clean review">
**Root causes:** <why they occurred, or "n/a">
**Preventions:** <what agents should check going forward>
**Domains affected:** <agents>
```

The `patterns.md` audit log is never soft-skipped, even when the finding repeats something an
`accepted` ADR already documents — a repeat violation of an accepted convention is itself
recurrence evidence that `/sdlc:adr --distill` needs to see (per `adr-pipeline.md` §6's
Recurrence criterion), so suppressing this entry would starve distill of the exact signal that
justifies revisiting or reinforcing the ADR. The ADR-index guard below applies only to the
per-agent memory append (item 2), never to this audit log.

**ADR-index check (applies to item 2 only, below).** Before the per-agent memory append, consult
`docs/adr/index.md` in `$WORKTREE` — the relevant agent's section(s) plus `General` — if it
exists. If a **`status: accepted`** ADR already captures the learning, **soft-skip that append and
note it** (the ADR is canonical). A match against a `superseded`, `rejected`, or `proposed` ADR
does **NOT** skip — the learning is still appended, since the index line carries status and lets
this check filter without opening the ADR. A missing index (repo has no ADRs yet) is a no-op —
append as normal. Additive guard: never changes the append format below; the skip is always soft
(skipped, never failed).

**2. Agent memory** — for each agent that fixed something, append a
`## ${DATE} — Story <STORY-KEY> — review fix` block to
`$WORKTREE/.claude/memories/agents/<agent-name>.md` (cross-cutting → `shared.md`) with Learnings +
Pitfalls. Then commit and push, both from the worktree:

```bash
git -C "$WORKTREE" add .claude/memories/
git -C "$WORKTREE" commit -m "chore: update learnings after <STORY-KEY> review"
git -C "$WORKTREE" push origin <BRANCH_PREFIX>/<STORY-KEY>
```

## Step 6 — Quality gate

```bash
git -C "$WORKTREE" fetch origin <BRANCH_PREFIX>/<STORY-KEY> && git -C "$WORKTREE" merge --ff-only origin/<BRANCH_PREFIX>/<STORY-KEY>
```

**Before running the gate, assert `$WORKTREE` is clean.** The gate now runs in the shared,
persistent `$WORKTREE` where an earlier fix-round agent may have left uncommitted or untracked
files behind (e.g. a forgotten `git add` of a new source file) — the gate would then pass against a
tree that isn't actually what got pushed, a false green.

```bash
[ -z "$(git -C "$WORKTREE" status --porcelain)" ] \
  || { echo "STOP: \$WORKTREE has stray uncommitted/untracked files before the quality gate — $(git -C "$WORKTREE" status --porcelain)"; exit 1; }
```

A non-empty result → list the stray files and **STOP** (same blocked shape as elsewhere in this
playbook — dispatch the owning domain agent to either commit or discard them; never silently clean
them yourself).

Run the quality-gate commands from `.claude/project/project-context.md` (Tooling + Quality Gate)
**inside `$WORKTREE`** (`cd "$WORKTREE"` first — never the primary checkout), with the shared Nx
cache exported so the gate run hits the warm cache (spec §3):

```bash
export NX_CACHE_DIRECTORY="$NX_CACHE_DIRECTORY"
cd "$WORKTREE"
# ... run the project-context Tooling + Quality Gate commands here ...
```

If the change touched infra, also run the infra build with the stage flag from project-context (still inside `$WORKTREE`).

Any failure → identify the workspace from the error, dispatch the owning domain agent with the
**exact** error (Step 3 protocol), push, and re-run the FULL gate (inside `$WORKTREE`). Repeat until clean. Paste the
actual gate output — never claim a pass without it (`verification-before-completion`).

> Treat the project-context quality-gate commands as a real gate: the test command may run
> `.ts` via a transpiler and pass THROUGH type errors. Also confirm no compiled `.js` shadows
> source — a green test suite does not prove
> the deployed bundle is correct (consult the review-pattern memory at `.claude/memories/reviews/patterns.md` for prior findings).

## Step 7 — Verification before completion (AC + plan check)

Apply `verification-before-completion`. Produce line-by-line checklists, each item confirmed
with evidence (git log, file existence, or test output) — no item checked off on assertion alone:

1. **Every plan task** in `docs/superpowers/plans/<STORY-KEY>.md` → has a corresponding commit/file/test.
   _(Full path only. On the lightweight path there is no plan doc — skip this checklist; the AC
   checklist below is the completion contract.)_
2. **Every acceptance criterion** on the Jira story → is met by code that exists on the branch,
   with the specific evidence (handler/test/file) named. _(Always — and the primary gate on the
   lightweight path.)_

**On the defect path (`WORK_KIND=defect`) — ALSO require the systematic-debugging completion
contract (AC17).** A defect has **no plan doc**, so checklist 1 is skipped (as on any lightweight
path); the AC checklist (2) still applies, and **in addition** the following regression-evidence
contract MUST hold — without it, return `blocked` (never `clean`):

1. **A regression test that FAILED before the fix and PASSES after.** Take the evidence from the
   branch's **own commit sequence**, NOT a `BASE_SHA` checkout:
   - at the **phase-3 commit** (regression test added, phase-4 fix not yet applied) the test **fails
     as an assertion** against the still-buggy behaviour;
   - at **HEAD** (fix applied) it **passes**.

   > Why not `BASE_SHA`: at develop's merge-base the test file does not yet exist, so running it
   > there fails to _compile/resolve_ rather than _assert_ — it cannot distinguish "failed because
   > the bug is present" from "failed to build". The **phase-3 commit** is the correct pre-fix point:
   > the test exists there and exercises code that compiles, failing only on the assertion the fix
   > later satisfies.

   ```bash
   # Identify the phase-3 commit (regression test added, before the fix), then show fail→pass.
   # Always inside $WORKTREE (the same one captured in Step 5) — never the primary checkout.
   git -C "$WORKTREE" fetch origin <BRANCH_PREFIX>/<STORY-KEY>
   git -C "$WORKTREE" log ${BASE_SHA}..origin/<BRANCH_PREFIX>/<STORY-KEY> --oneline   # locate the phase-3 (test) commit
   git -C "$WORKTREE" checkout <phase-3-sha>          # detached, inside $WORKTREE only
   # run the regression test here: FAILS (assertion) against the still-buggy behaviour — paste output.
   git -C "$WORKTREE" checkout <BRANCH_PREFIX>/<STORY-KEY>   # back to HEAD, inside $WORKTREE
   # run the regression test here again: PASSES — paste output.
   ```

2. **The full test suite passes with no regressions** (the Step-6 gate output covers this).

This is **in addition** to the existing lightweight ACs-as-contract fallback — the defect path
_adds_ the failing→passing regression-test requirement. (No double-verify: systematic-debugging
phase-4 is the _implementer's_ inner check that the fix works; this Step-7 contract is QA's _outer_
gate proving the regression evidence + clean suite.)

```bash
git -C "$WORKTREE" fetch origin <BRANCH_PREFIX>/<STORY-KEY>
git -C "$WORKTREE" log ${BASE_SHA}..origin/<BRANCH_PREFIX>/<STORY-KEY> --oneline
```

Any plan task or AC with no corresponding evidence → dispatch the owning domain agent to
complete it (Step 3 protocol), then re-run Steps 6–7. On the defect path, a regression test that
does **not** fail-before / pass-after → return `blocked`. Do not return `clean` with an unmet AC.

## Step 8 — Return verdict to the Principal Engineer

Return exactly this block (the caller creates the PR only on `clean`):

```
## QA verdict: <STORY-KEY>
Status: clean | blocked
Review rounds: <N>
Fixed (Critical/Important): <list, or "none">
Minor noted (not fixed): <list, or "none">
AC check: <met — all N ACs evidenced | UNMET: <which> >
Quality gate: typecheck pass | tests pass   (paste evidence)
Learnings: written to patterns.md + <agent memory files>
Blocked reason: <one line — only if Status: blocked>
```

- `Status: clean` only when: review has no Critical/Important findings, every AC is evidenced,
  the gate is green with pasted output, and learnings are committed + pushed.
- `Status: blocked` at any unrecoverable point (agent blocked, push conflict, AC cannot be met)
  → return immediately with the reason; do not improvise around it.

## Constraints

- Never write feature code yourself — dispatch the owning domain agent; you coordinate the loop.
- Never run two domain agents at once.
- YOU push; domain fix agents only commit.
- Never return `clean` with a failing gate, an unmet AC, or an unverified security finding.
- Paste real gate/log output — never claim a pass without evidence (`verification-before-completion`).
- Never create the PR — that is the Principal Engineer's step, run only after you return `clean`.
- Never dispatch a `qa-engineer` subagent — run this playbook inline.
