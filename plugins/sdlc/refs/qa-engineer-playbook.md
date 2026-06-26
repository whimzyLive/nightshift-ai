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

| | Story mode | Diff mode (ad-hoc, no story key) |
|---|---|---|
| Trigger | `<STORY-KEY>` provided | no story key — review the current diff |
| Review target | commit range `BASE_SHA..origin/<BRANCH_PREFIX>/<STORY-KEY>` | **single-point working-tree diff** `git diff <BASE_SHA>` (committed-unmerged + staged + **uncommitted**) + untracked files, where `BASE_SHA = git merge-base origin/develop HEAD` — NOT a commit range (a commit range cannot see uncommitted edits) |
| Requirements given to reviewer (Step 1) | plan + acceptance criteria | the change's own intent (commit subjects + changed-file summary) — there are no ACs |
| Fix commits (Step 3) | committed by domain agent, **pushed** by you to `<BRANCH_PREFIX>/<STORY-KEY>` | applied in the **working tree**, committed only if the change set was already committed; **never pushed** — leave for the user |
| Learnings memory (Step 5) | required | **skip** — no story to key the entry to |
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
  exclusion is inline threads explicitly marked *Resolved* (filtered at fetch via GraphQL
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

For each Critical / Important group (grouped by domain), dispatch the owning domain agent with
the `Agent` tool, **`isolation: "worktree"`** (it writes code). The prompt MUST include:

1. Story key.
2. The reviewer findings for that domain, **verbatim**.
3. "Branch `<BRANCH_PREFIX>/<STORY-KEY>` already exists on remote. Check it out, fix ONLY these issues, and
   commit (use the `conventional-commit` skill). Do NOT push — the QA loop handles pushes."
4. "Append non-obvious learnings to `.claude/memories/agents/<your-name>.md` and stage it with
   your commit."
5. "Use the package manager and infra stage flag from project-context (Tooling) on every infra CLI command."
6. "Return exactly:\n  Status: complete|blocked\n  Note: <one line if blocked>\n  Summary: <one line — what changed>"

After the agent returns, push and confirm:

```bash
git push origin <BRANCH_PREFIX>/<STORY-KEY>
git fetch origin <BRANCH_PREFIX>/<STORY-KEY>
git log origin/<BRANCH_PREFIX>/<STORY-KEY> --oneline -3
```

- No new commit since pre-dispatch HEAD → agent failed silently. **Return `blocked`** to the
  Principal Engineer with the reason.
- `Status: blocked` → **return `blocked`** immediately; do not attempt the fix yourself.

## Step 4 — Re-review

After all fixes are pushed, repeat Steps 1–3 until the reviewer returns **no Critical/Important
findings and no open AC gaps**. Minor issues: collect for the return report, do not loop.

## Step 5 — Write learnings to memory

After review rounds are clean, sync and record what was learned so future implementations avoid
the same mistakes.

```bash
git fetch origin <BRANCH_PREFIX>/<STORY-KEY> && git merge --ff-only origin/<BRANCH_PREFIX>/<STORY-KEY>
DATE=$(date +%Y-%m-%d)
```

**1. Audit log** — append to `.claude/memories/reviews/patterns.md`:

```
## ${DATE} — Story <STORY-KEY>
**Issues found:** <Critical/Important + any AC/security gaps, or "none — clean review">
**Root causes:** <why they occurred, or "n/a">
**Preventions:** <what agents should check going forward>
**Domains affected:** <agents>
```

**2. Agent memory** — for each agent that fixed something, append a
`## ${DATE} — Story <STORY-KEY> — review fix` block to
`.claude/memories/agents/<agent-name>.md` (cross-cutting → `shared.md`) with Learnings +
Pitfalls. Then commit and push:

```bash
git add .claude/memories/
git commit -m "chore: update learnings after <STORY-KEY> review"
git push origin <BRANCH_PREFIX>/<STORY-KEY>
```

## Step 6 — Quality gate

```bash
git fetch origin <BRANCH_PREFIX>/<STORY-KEY> && git merge --ff-only origin/<BRANCH_PREFIX>/<STORY-KEY>
```

Run the quality-gate commands from `.claude/project/project-context.md` (Tooling + Quality Gate). If the change touched infra, also run the infra build with the stage flag from project-context.

Any failure → identify the workspace from the error, dispatch the owning domain agent with the
**exact** error (Step 3 protocol), push, and re-run the FULL gate. Repeat until clean. Paste the
actual gate output — never claim a pass without it (`verification-before-completion`).

> Treat the project-context quality-gate commands as a real gate: the test command may run
> `.ts` via a transpiler and pass THROUGH type errors. Also confirm no compiled `.js` shadows
> source — a green test suite does not prove
> the deployed bundle is correct (consult the review-pattern memory at `.claude/memories/reviews/patterns.md` for prior findings).

## Step 7 — Verification before completion (AC + plan check)

Apply `verification-before-completion`. Produce line-by-line checklists, each item confirmed
with evidence (git log, file existence, or test output) — no item checked off on assertion alone:

1. **Every plan task** in `docs/superpowers/plans/<STORY-KEY>.md` → has a corresponding commit/file/test.
   *(Full path only. On the lightweight path there is no plan doc — skip this checklist; the AC
   checklist below is the completion contract.)*
2. **Every acceptance criterion** on the Jira story → is met by code that exists on the branch,
   with the specific evidence (handler/test/file) named. *(Always — and the primary gate on the
   lightweight path.)*

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
   > there fails to *compile/resolve* rather than *assert* — it cannot distinguish "failed because
   > the bug is present" from "failed to build". The **phase-3 commit** is the correct pre-fix point:
   > the test exists there and exercises code that compiles, failing only on the assertion the fix
   > later satisfies.

   ```bash
   # Identify the phase-3 commit (regression test added, before the fix), then show fail→pass.
   git fetch origin <BRANCH_PREFIX>/<STORY-KEY>
   git log ${BASE_SHA}..origin/<BRANCH_PREFIX>/<STORY-KEY> --oneline   # locate the phase-3 (test) commit
   # at the phase-3 commit the new test FAILS (assertion); at HEAD it PASSES — paste both outputs.
   ```
2. **The full test suite passes with no regressions** (the Step-6 gate output covers this).

This is **in addition** to the existing lightweight ACs-as-contract fallback — the defect path
*adds* the failing→passing regression-test requirement. (No double-verify: systematic-debugging
phase-4 is the *implementer's* inner check that the fix works; this Step-7 contract is QA's *outer*
gate proving the regression evidence + clean suite.)

```bash
git fetch origin <BRANCH_PREFIX>/<STORY-KEY>
git log ${BASE_SHA}..origin/<BRANCH_PREFIX>/<STORY-KEY> --oneline
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
