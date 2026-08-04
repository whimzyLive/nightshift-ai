# QA Engineer Playbook (post-implementation quality loop)

<!-- notation: `:=` define, `->` leads-to, `⊆` drawn-from-set, ASSERT/ELSE guard, first-match-wins ordering. Full legend: refs/pseudocode-notation.md -->

The code-quality lifecycle for a Jira story implementation. **This playbook is executed
INLINE by the top-level session** — it is invoked by the Principal Engineer playbook
(`${CLAUDE_PLUGIN_ROOT}/refs/principal-engineer-playbook.md`, Step 6) once all domain-agent
implementation phases are pushed to `<BRANCH_PREFIX>/<STORY-KEY>`. It is NOT dispatched as a subagent.

## Why inline

# rationale: refs/design-notes/inline-orchestration-rationale.md

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
- The phase ledger — **optional**; a cache Step 3 resolves (git-reconstruction fallback) before
  dispatching each fix agent, never a STOP when absent (D3).

## Modes

The loop runs in one of two modes. The caller picks the mode; the steps below are written for
**Story mode** (the default, used by `/impl` and `/review <STORY-KEY>`). **Diff mode** is the
lean ad-hoc variant used by `/review` with no story key — it reviews the current change set with
no Jira ticket, plan, or PR.

|  | Story mode | Diff mode (ad-hoc, no story key) |
| --- | --- | --- |
| Trigger | `<STORY-KEY>` provided | no story key — review the current diff |
| Review target | commit range `BASE_SHA..origin/<BRANCH_PREFIX>/<STORY-KEY>` | **single-point working-tree diff** `git diff <BASE_SHA>` (committed-unmerged + staged + **uncommitted**) + untracked files, where `BASE_SHA = git merge-base origin/develop HEAD` — NOT a commit range (a commit range cannot see uncommitted edits) |
| Requirements given to reviewer (Step 1) | plan + acceptance criteria | the change's own intent (commit subjects + changed-file summary) — there are no ACs |
| Fix commits (Step 3) | committed by domain agent, **pushed** by you to `<BRANCH_PREFIX>/<STORY-KEY>` | applied in the **working tree**, committed only if the change set was already committed; **never pushed** — leave for the user |
| Review file + rule entries (Step 5) | required | **skip** — no story to key the entry to |
| AC + plan verification (Step 7) | required | **skip the AC/plan checklist**; instead confirm every review finding is resolved and the gate is green |
| Verdict (Step 8) | full block incl. AC + learnings lines | drop the `AC check` and `Learnings` lines; add `Fixes: applied in working tree (not pushed)` |

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

**Pre-review consult.** Before dispatching the reviewer, scan the frontmatter of
`.claude/memories/reviews/*.md` (excluding the legacy `patterns.md`, flagged separately by
`check-frontmatter.sh`) for prior rounds whose `domains` or `root_causes` overlap this story's
domains — open the full body only for the rounds that actually overlap, not every file. This
replaces reading a single append-only audit log whole.

Captured round files are not committed, so also read them:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/list-captured.sh --kind review`

Dispatch an `agent-skills:code-reviewer` subagent following the `requesting-code-review`
skill pattern. The prompt MUST include:

- `DESCRIPTION`: Story mode — "Implementation of <STORY-KEY> — <story summary>"; Diff mode —
  the change's own intent (commit subjects + changed-file summary).
- `PLAN_OR_REQUIREMENTS`: Story mode — the story's **acceptance criteria verbatim** (the reviewer
  must check the code against the ACs, not just internal consistency), **plus** the path to
  `docs/superpowers/plans/<STORY-KEY>.md` **when that file exists** — the reviewer reads it itself. On the
  **lightweight** path there is no plan doc — use the Jira story **description + acceptance criteria**
  as the requirement source (the ACs are the contract). Diff mode — there are no ACs/plan; the
  requirement is the change's stated intent.
- The review target: Story mode — `BASE_SHA..HEAD_SHA`; Diff mode — the `git diff <BASE_SHA>`
  working-tree diff plus any untracked files (NOT a commit range).
- Explicit instruction to review across all five axes: **correctness, readability,
  architecture, security, performance** — and (Story mode) to flag any AC that is not demonstrably
  met and any regression risk to existing behavior.
- Explicit instruction (readability axis) to flag any new informative/explanatory code comment the
  diff introduces, per the shared rule at `${CLAUDE_PLUGIN_ROOT}/refs/code-comments-policy.md` —
  point the reviewer at that file for the exact definition and the language/lint-required
  exclusions rather than restating the rule in the dispatch prompt.

Dispatch with `isolation: "worktree"` is NOT needed — the reviewer reads, it does not write.

### Alternative entry — external review feedback (`/review-fix`)

When findings come from an existing **GitHub PR or commit** (Copilot or human reviewers) rather
than a fresh code-reviewer pass, SKIP the dispatch above. Instead build the finding list from the
fetched comments:

- The caller (`/review-fix`) has fetched the feedback into files under the session temp dir
  (`dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)`): `"$dir/review-fix-summary.json"` = PR
  **body** + general/issue comments + review-summary bodies; `"$dir/review-fix-inline.json"` =
  **unresolved** inline review comments. Read BOTH — the only exclusion is inline threads marked
  _Resolved_ (filtered at fetch via GraphQL `reviewThreads.isResolved`, already addressed). The PR
  body and generic comments have no resolved state and are ALWAYS included.
- Each inline comment becomes one candidate finding; treat the PR body + general comments as
  context AND as potential candidate requests in their own right. Keep each comment's file/line
  anchor, author, AND its numeric `id` (databaseId), required to reply on and resolve that exact
  thread in the close-out step. (Do NOT re-triage already-resolved threads — excluded at fetch.)
- Treat these EXACTLY as if a reviewer had produced them, then proceed to Step 2 triage — where you
  decide which are real (`receiving-code-review`). Record a decision ledger row per comment:
  `{id, path:line, decision: accepted|rejected, justification}`.

This mode operates on the **PR head branch** (or the commit's branch): Step 3 fix commits are
committed AND **pushed** there, so the PR updates and reviewers see the resolution. Step 4's
re-review is a fresh `agent-skills:code-reviewer` pass over the **applied fix commits**
(`BASE_SHA`=pre-fix HEAD, `HEAD_SHA`=post-fix HEAD), confirming each accepted comment is resolved
and nothing regressed.

**Close out the PR threads (fixes pushed + gate green — `/review-fix` only).** Post each decision
back so the reviewer sees only what still needs attention, each with a justification. For every
triaged inline comment, write the reply to a file (never inline JSON) and call the helper:

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)   # session-scoped ./.tmp/<key>
bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-resolve-comment.sh <PR> <comment-id> accepted "$dir/reply-<id>.md"   # replies + RESOLVES the thread
bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-resolve-comment.sh <PR> <comment-id> rejected "$dir/reply-<id>.md"   # replies, leaves thread OPEN
```

- **Accepted** → reply with why + the fix commit; thread RESOLVES (drops off the open list).
- **Rejected** → reply why it's wrong/stale/out-of-scope; thread stays OPEN.
- Review-summary/top-level issue comments aren't resolvable threads → post ONE summarising PR
  issue comment (`gh pr comment`) instead.
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
- **Informative/explanatory comment** (per `${CLAUDE_PLUGIN_ROOT}/refs/code-comments-policy.md`) —
  treat as **Important**: the fix requests the comment be removed and, if it captured real
  non-obvious context, that the introducing agent capture it as a rule entry instead (per the
  admission test in `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`). A comment required by
  language/lint convention (per that same doc's exclusions) is not a finding.

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

Record the reuse decision (AC-3, rolled into Step 8's verdict):

```text
SDLC agent reuse = disabled -> fresh Agent(...), REUSE=false, reason=disabled-by-config
reused instance available -> SendMessage resume, REUSE=true, reason=reused
reused instance unavailable, session boundary -> fresh Agent(...), REUSE=false, reason=fallback-session-boundary
reused instance already returned/terminated -> fresh Agent(...), REUSE=false, reason=fallback-instance-terminated
```

**Resolve the phase ledger row before building the prompt** (a cache, never required):

```text
ledger_file := $(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)/phase-ledger.txt
ledger_file readable -> select the row whose LEDGER_AGENT matches the dispatch target
ledger_file absent -> reconstruct: git -C "$WORKTREE" diff --name-only BASE_SHA..origin/<BRANCH_PREFIX>/<STORY-KEY>, group by the project-context workspace->agent table   # a fresh session after Step-7 teardown has no temp dir
reconstruction fails -> dispatch without a ledger   # never a STOP: the ledger is an optimisation, not a contract input
no row matches the dispatched domain -> dispatch without a ledger row
```

A resolved row is placed before item 4's findings below.

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
7. "Capture any admitted rule entries per the admission test in
   `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`'s memory-write section."
8. "Use the package manager and infra stage flag from project-context (Tooling) on every infra CLI command."
9. "Return exactly (per `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md` — 4 lines complete, 5 lines blocked):\n Status: complete|blocked\n Note: <one line if blocked, else omit>\n Summary: <one line — what changed>\n Skills loaded: <comma-separated override skill names | none>\n Rules applied: <rule-id>, <rule-id> | none"
10. "Context reuse: a path already read in full in this transcript is never re-read — see the `## Context reuse` section of ${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md."
11. "Bounded reads: Grep-first, then Read with `offset`/`limit` for files over ~400 lines — see the `## Bounded reads` section of `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`."

**Before dispatching**, snapshot the primary checkout's state (spec §5, same machine guard as
principal playbook Step 5) — a snapshot to diff against later, not an assertion; the primary may
already be dirty (unrelated developer WIP), and that pre-existing dirt is not itself a violation:

```text
snap := bash ${CLAUDE_PLUGIN_ROOT}/scripts/assert-workspace-clean.sh snapshot <primary-root>
# -> PRIMARY_HEAD, PRIMARY_STATE_FILE, PRIMARY_PRE_DIRTY (keep PRIMARY_STATE_FILE for the assert call below)
PRIMARY_PRE_DIRTY == 'true' -> print the one-line warning below, then proceed  # never a blocked
```

`WARNING: primary checkout has pre-existing uncommitted changes unrelated to this story —
snapshotting and comparing, not blocking`. Do not return `blocked` on pre-existing dirt you didn't
cause — that consequence stays here, not in the script.

After the agent returns, push and confirm from the worktree:

```bash
git -C "$WORKTREE" push origin <BRANCH_PREFIX>/<STORY-KEY>
git fetch origin <BRANCH_PREFIX>/<STORY-KEY>
git log origin/<BRANCH_PREFIX>/<STORY-KEY> --oneline -3
```

Then assert the primary checkout matches its pre-dispatch snapshot exactly:

```text
assert := bash ${CLAUDE_PLUGIN_ROOT}/scripts/assert-workspace-clean.sh assert <primary-root> $PRIMARY_STATE_FILE
# -> WORKSPACE_INTEGRITY ⊆ {OK, VIOLATED}, WORKSPACE_VIOLATION ⊆ {none, head-moved, worktree-changed, both}
WORKSPACE_INTEGRITY == 'VIOLATED' -> BLOCKED: fix agent wrote to the primary checkout instead of $WORKTREE
```

The script's OK/none is exact-match against the snapshot (NOT asserted empty) — a pre-dirty
primary that stays at the same dirt still passes; only a *change* from the captured snapshot is a
violation.

If `WORKSPACE_INTEGRITY=VIOLATED` → **return `blocked`** immediately with that reason (same
detectable-failure shape as the principal playbook's Step-5 guard) — do not attempt to fix or
revert it yourself. Never self-repair.

- No new commit since pre-dispatch HEAD (on `$WORKTREE`) → agent failed silently. **Return `blocked`**
  to the Principal Engineer with the reason.
- `Status: blocked` → **return `blocked`** immediately; do not attempt the fix yourself.
- **Verify `Skills loaded` covers the named set.** Same mechanical rule as principal playbook Step 5
  (source of truth — do not re-derive here); the QA-specific consequence differs: missing/failed →
  return `blocked` immediately, no redispatch. (Applies only to `Status: complete` returns, and
  extra skills the agent lists beyond the named set still pass, per Step 5.)
- **Verify the return carries `Rules applied:`** (4 lines complete, 5 lines blocked, per
  `domain-agent-handoff.md`) — an absent line is the same contract violation as a missing
  `Skills loaded:` line: return `blocked` immediately, no redispatch. `none` is a valid value.

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

**1. Review round file** — capture unconditionally, every round, via the script's own PRIMARY
checkout resolution (never `$WORKTREE`, which worktree-gc.sh deletes):

```text
bash ${CLAUDE_PLUGIN_ROOT}/scripts/capture-learning.sh review <STORY-KEY> ${DATE} <round-number> <payload-file>
round 1 -> no suffix; round N >= 2 -> the script appends -rN
issue_count: 0 -> pass `-` for the payload (frontmatter only)
issue_count > 0 -> payload carries `domains`, `root_causes`, `issue_count` frontmatter + the ## Issues / ## Preventions / ## Rules written body
never soft-skip — a finding repeating an `accepted` ADR is itself recurrence evidence `/sdlc:docs distill` needs (adr-pipeline.md §6)
```

Frontmatter is the 5-field review schema:

```yaml
---
story: <STORY-KEY>
date: <YYYY-MM-DD> # must match the filename
domains: [<agent>, ...] # agents this round touched; [] only when issue_count is 0
root_causes: [<token>, ...] # from ${CLAUDE_PLUGIN_ROOT}/refs/root-cause-vocab.txt; [] only when issue_count is 0
issue_count: <N> # count of Critical + Important findings this round
---
```

A round with findings adds this body:

Artifact encoding contract: unpadded tables, no section dropped, one-line N/A, verbatim contracts, rationale as annotation, prose < 10 lines between headings. plugins/sdlc/refs/artifact-encoding.md

```
## Issues
<one bullet per Critical/Important + any AC/security gap>

## Preventions
<what agents should check going forward>

## Rules written
<list of rule ids created from this round, or "none">
```

**2. Rule entries** — for each agent that fixed something this round, capture a rule entry for the
**fixing agent** (never `qa-engineer`) for any candidate passing the admission test in
`${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md` (ADR-0004; schema/test not restated here):

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/capture-learning.sh rule <fixing-agent>/<rule-id> <STORY-KEY> <payload-file>`

Payload frontmatter carries `origin: qa-round`. Cross-cutting → `shared/`. Creates only — never edits
or deletes an existing rule file. List captured ids in `## Rules written`.

**3. Counter-only updates** — for any existing rule a finding proves was violated, capture a
counter-only record with `uses: 1` and `evidence: [<STORY-KEY>]`; promotion merges it into the
target's existing count. You never edit the committed rule file.

## Step 6 — Quality gate

```text
offload := Agent("general-purpose", <STORY-KEY> <WORKTREE> <NX_CACHE_DIRECTORY> <BRANCH_PREFIX>,
  "Follow ${CLAUDE_PLUGIN_ROOT}/refs/qa-gate-runner.md exactly. Return ONLY its block.")
Stray files non-empty -> STOP, list; never clean
Gate:fail -> dispatch Owning agent w/Error(Step3), push, re-offload fresh
Gate:pass,Evidence="" | no Gate: key -> re-offload once, fallback
fallback := Read qa-gate-runner.md, run INLINE; offload=inline-fallback
carry Evidence -> Step-8 `Quality gate:`
```

Any failure → identify the workspace from the error, dispatch the owning domain agent with the
**exact** error (Step 3 protocol), push, and re-run the FULL gate (inside `$WORKTREE`). Repeat until clean. Paste the
actual gate output — never claim a pass without it (`verification-before-completion`).

## Step 7 — Verification before completion (AC + plan check)

Follow `${CLAUDE_PLUGIN_ROOT}/refs/ac-verification.md` — the plan-task checklist, the AC
checklist, and (on `WORK_KIND=defect`) the regression-evidence contract all live there.

```text
offload := Agent("general-purpose", <STORY-KEY> <WORKTREE> <BRANCH_PREFIX> <BASE_SHA> <WORK_KIND>,
  "Follow ${CLAUDE_PLUGIN_ROOT}/refs/ac-verification.md. Return ONLY its block.")
Unmet non-empty -> dispatch each Owner(Step3), push, rerun 6-7
WORK_KIND=defect,Regression evidence n/a|!fail-before/pass-after -> blocked
no Verification: -> re-offload once, fallback
fallback := Read ac-verification.md INLINE; offload=inline-fallback
never -> clean while Unmet non-empty
carry result -> Step-8 AC check:
```

**The full test suite passing with no regressions is covered by the Step-6 gate output** — the
verifier's regression-evidence contract does not re-run it.

Any plan task or AC with no corresponding evidence → dispatch the owning domain agent to
complete it (Step 3 protocol), then re-run Steps 6–7. On the defect path, a regression test that
does **not** fail-before / pass-after → return `blocked`. Do not return `clean` with an unmet AC.

## Step 8 — Return verdict to the Principal Engineer

Return exactly this block (the caller creates the PR only on `clean`):

```
## QA verdict: <STORY-KEY>
Status: clean | blocked
Review rounds: <N>
Fix dispatch: reuse <N> / fresh <N>
Fixed (Critical/Important): <list, or "none">
Minor noted (not fixed): <list, or "none">
AC check: <met — all N ACs evidenced | UNMET: <which> >
Quality gate: typecheck pass | tests pass   (paste evidence)
Learnings: captured to <N> file(s): <ids, or "none">
Blocked reason: <one line — only if Status: blocked>
```

- `Status: clean` only when: review has no Critical/Important findings, every AC is evidenced,
  the gate is green with pasted output, and learnings are captured.
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
