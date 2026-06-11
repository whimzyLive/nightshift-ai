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
- Plan path derived deterministically: `docs/superpowers/plans/<STORY-KEY>.md`

## Project constants

All project constants — base branch, quality gate, package manager, infra stage flag, active
agents — live in `.claude/project/project-context.md`. Read it first. This playbook references
them as tokens (`<BASE-BRANCH>`, `feat/<STORY-KEY>`) and never hardcodes values.

Skip phases for agents marked **Standby** in project-context.

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

## Step 1 — Pre-flight checks

```bash
# 1. Plan must exist (merged to develop)
test -f "docs/superpowers/plans/<STORY-KEY>.md" \
  || { echo "STOP: plan not found — merge the plan PR first"; exit 1; }

# 2. Sync develop, capture base SHA BEFORE branching (needed for review range)
git fetch origin develop
BASE_SHA=$(git rev-parse origin/develop)

# 3. No implementation PR already open
gh pr list --search "feat/<STORY-KEY>" --json number,title,headRefName,state

# 4. Dependency gate — every story that BLOCKS this one must already have a feat/* PR.
#    Deterministic, single statically-analyzable call (allowlisted Bash(bash ./${CLAUDE_PLUGIN_ROOT}/scripts/*)).
#    The script resolves the parent epic, derives blockers by sibling-inversion
#    (a sibling S blocks <STORY-KEY> iff S's links have outwardIssueKey == <STORY-KEY>),
#    and verifies each blocker has a feat/<blocker> PR. acli is the only source of truth —
#    any acli query error => GATE=STOP. See ${CLAUDE_PLUGIN_ROOT}/scripts/dep-gate.sh.
#    NOTE: resolving the epic REQUIRES `acli workitem view KEY --fields parent` — the default
#    `view --json` strips `parent` and returns empty (this was a real gate-failure bug).
bash ./${CLAUDE_PLUGIN_ROOT}/scripts/dep-gate.sh <STORY-KEY>   # exit 0 = GATE=PASS, exit 1 = GATE=STOP (REASON= printed)
```

- Plan missing → **STOP**, tell user to merge the plan PR.
- Implementation PR already merged → **STOP**, report it's already done.
- An open `feat/<STORY-KEY>` PR/branch already exists → reuse it (check it out); do not create a duplicate.
- **Any blocker has no `feat/<blocker>` PR (open or merged) → STOP the entire flow and REJECT.** Do not create a branch, do not dispatch any domain agent. Report to the user:
  ```
  BLOCKED — <STORY-KEY> cannot be implemented yet.
  Missing upstream work: <blocker-key(s) with no feat/* PR>.
  These dependencies must reach at least an open feat/* PR before <STORY-KEY> starts.
  Next step: implement <blocker-key> first (or remove the Jira "Blocks" link if stale).
  ```
  This gate enforces the Jira dependency graph (kept in the Epic PRD's "Story Dependency Graph" section) — never implement a story ahead of the work it depends on.

## Step 2 — Read & parse the plan

1. Read `docs/superpowers/plans/<STORY-KEY>.md`.
2. Group tasks by agent tag: `[database-administrator]`, `[platform-engineer]`,
   `[sync-engineer]`, `[web-engineer]`, `[mobile-engineer]`.
3. Cross-reference Active agents in project-context — drop Standby phases with no tasks.
4. Note any "grounding corrections" / "open items" the plan flagged — pass them verbatim into
   the relevant domain-agent prompt so the implementer honors them.

## Step 3 — Create the implementation branch (YOU do this)

```bash
git checkout -b feat/<STORY-KEY> origin/develop 2>/dev/null \
  || git checkout feat/<STORY-KEY>
git push -u origin feat/<STORY-KEY>
```

Domain agents never create branches or PRs. PR is opened only in Step 7, after QA returns `clean`.

## Step 4 — Dispatch domain agents (NON-NEGOTIABLE order, one at a time)

```
Phase 1 — [database-administrator]  schema + entities + migrations (ALWAYS FIRST; skip if Standby/no tasks)
Phase 2 — [platform-engineer]       backend infra + handlers + config
Phase 3 — [sync-engineer]           offline-sync rules + transactions (only if plan has tasks)
Phase 4 — [web-engineer]            web pages/components (only if plan has tasks)
Phase 5 — [mobile-engineer]         mobile screens (only if plan has tasks)
```

- Sequential only — never two domain agents at once.
- Each phase verified complete before the next is dispatched.

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
4. "Branch `feat/<STORY-KEY>` already exists on remote and is checked out. Do NOT create a new
   branch. Check it out, do your work, and commit."
5. "Do NOT create a PR — the orchestrator opens one after all phases and review are clean."
6. "Commit your changes (use the `conventional-commit` skill; scope from the `packages/` dir
   name). Do NOT push — the orchestrator handles pushes."
7. "Append non-obvious learnings to `.claude/memories/agents/<your-name>.md` and stage it with
   your commit (per `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`)."
8. "Use the package manager and infra stage flag from project-context (Tooling) on every infra CLI command."
9. "Return exactly:\n  Status: complete|blocked\n  Note: <one line if blocked>\n  Summary: <one line — files changed, key entities/handlers touched>"

Never send just a task title.

## Step 5 — Phase completion verification (after EACH phase)

```bash
git log feat/<STORY-KEY> --oneline -5      # local HEAD must have advanced
git push origin feat/<STORY-KEY>           # YOU push
git fetch origin feat/<STORY-KEY>
```

- No new commits since pre-dispatch HEAD → agent failed silently. **STOP**, report.
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
- The pushed `feat/<STORY-KEY>` branch
- The Jira story summary + acceptance criteria (fetched by the caller)

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

```bash
PR_URL=$(gh pr create \
  --title "[<STORY-KEY>] <story summary>" \
  --body "Implementation for <STORY-KEY>. All phases complete, review clean, quality gate passed." \
  --base develop \
  --head feat/<STORY-KEY>)
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
## Feature: <name>  (Branch: feat/<STORY-KEY>)
### Phases: <agents that ran + one-line summaries>
### QA: rounds <N>; fixed <Critical/Important list>; minor noted <list>; ACs <met — all N evidenced>
### Quality gate: typecheck pass | tests pass   (QA evidence)
### PR: <PR_URL>
### Status: all phases complete, QA verdict clean, gate passed, PR ready.
```

## Constraints

- Never start a story whose Jira blockers lack a `feat/*` PR — the Step 1 dependency gate STOPs and rejects (no branch, no agents).
- Never skip the dependency order; never run two domain agents at once.
- YOU create the branch and push; domain agents only commit.
- The code-quality loop (review/fix/learn/gate/AC-verify) is owned by the QA Engineer (Step 6) — run it inline, do not duplicate it here.
- PR opened by YOU only after the QA Engineer returns `Status: clean` — never before.
- Any agent `blocked`, or a QA `Status: blocked` → stop, report immediately, do not create the PR.
- Never implement feature code yourself — coordinate only.
- Never dispatch a `principal-engineer` (or `qa-engineer`) subagent — run both playbooks inline.
