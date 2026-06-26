---
description: Ingest review comments from a GitHub PR or commit, triage them with the receiving-code-review skill (keep only the ones true in this app's context), fix the accepted ones via the right domain agents, re-review the applied commits, then post each comment's accept/reject justification back on its PR thread — resolving accepted threads and leaving rejected ones open. Runs the QA Engineer playbook inline. Does not re-implement or open a PR.
---

Resolve external review feedback for **`$ARGUMENTS`** (a GitHub **PR** number/URL, or a **commit
SHA**): fetch every comment, triage which are real, fix the accepted ones via domain agents, and
re-review the applied commits. This pushes fix commits to the PR's head branch so the PR updates —
it does NOT re-implement the story or open a new PR.

**Do NOT dispatch a `qa-engineer` subagent.** Claude Code blocks subagent → subagent nesting, so a
dispatched qa-engineer cannot dispatch the `agent-skills:code-reviewer` subagent or the domain fix
agents it needs. You play the QA Engineer role directly, in the top-level session.

Repo slug: read `<owner>/<repo>` from `.claude/project/project-context.md` (GitHub → Org/repo).

## Steps

1. **Identify the target** from `$ARGUMENTS`:
   - **PR** (number or URL): read its head branch, base branch, and url:
     ```bash
     gh pr view <PR> --json number,headRefName,baseRefName,url,state
     ```
   - **Commit** (40-/7-hex SHA): the target is that commit on its current branch.

2. **Fetch the feedback** into the session temp dir (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh`
   — session-scoped `./.tmp/<key>`, never `/tmp`; write file, never inline JSON). The ONLY
   thing excluded is an inline thread explicitly marked *Resolved* (a reviewer ticked *Resolve*, or
   a prior `/review-fix` run resolved it — already addressed, needs no fixing). EVERYTHING else is
   pulled in as context: the **PR body**, every **issue/general comment**, every **review-summary
   body**, and every **unresolved** inline thread. Generic comments and the PR body have no
   resolved state, so include them all — they often carry intent the inline notes assume:
   ```bash
   dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)   # session-scoped ./.tmp/<key>
   # PR description (body) + review-summary bodies + general/issue comments.
   # None of these are resolvable threads — there is no resolved state to filter, so keep all.
   gh pr view <PR> --json body,reviews,comments > "$dir/review-fix-summary.json"
   # PR: inline (line-anchored) review comments — ONLY those on an UNRESOLVED thread.
   # The REST .../pulls/<PR>/comments endpoint returns EVERY inline comment with no resolution
   # state, so it is NOT used here; this script filters via GraphQL reviewThreads.isResolved.
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-unresolved-comments.sh <PR> "$dir/review-fix-inline.json"
   # Commit target (instead of the two PR calls above) — commit comments have no resolved state:
   # gh api repos/<owner>/<repo>/commits/<SHA>/comments --paginate > "$dir/review-fix-inline.json"
   ```
   `pr-unresolved-comments.sh` emits NDJSON, one object per unresolved inline comment, each with
   its numeric `id` (databaseId), `path`, `line`, `author`, and `body` — the `id` is required later
   to reply on and resolve that exact thread. Read BOTH files: the summary file (body + general
   comments + review bodies) feeds context and may itself contain actionable requests; the inline
   file is the line-anchored findings. If there is zero feedback of any kind → STOP: "no actionable
   review feedback on <target> — nothing to triage".

3. **Check out the branch and pin the pre-fix HEAD** (so the re-review range is exactly the fixes):
   ```bash
   git fetch origin <headRefName> <baseRefName>
   git checkout <headRefName>
   PRE_FIX_HEAD=$(git rev-parse HEAD)
   BASE_SHA=$(git merge-base origin/<baseRefName> HEAD)
   ```
   (Commit target: `git checkout` its branch; `PRE_FIX_HEAD=$(git rev-parse HEAD)`.)

4. **Execute `${CLAUDE_PLUGIN_ROOT}/refs/qa-engineer-playbook.md` inline via its "Alternative entry — external
   review feedback (`/review-fix`)" path**, passing the fetched comment files, `BASE_SHA`,
   `PRE_FIX_HEAD`, and the head branch. That path runs:
   - **Triage (Step 2, `receiving-code-review`)** — for EACH comment record a decision ledger row:
     `{id, path:line, decision: accepted|rejected, justification}` (keep only comments **true in
     this app's context**; reject wrong/stale/out-of-scope ones with a one-line reason). You will
     post these justifications back on the PR in step 5.
   - **Fix loop (Step 3)** — dispatch the owning domain agent per ACCEPTED finding (file path →
     agent via project-context Workspace Structure); commits pushed to the head branch. Note the
     fix commit SHA per accepted comment for the reply.
   - **Re-review (Step 4)** — fresh `agent-skills:code-reviewer` over the applied fix commits
     (`PRE_FIX_HEAD..HEAD`) to confirm each accepted comment is resolved and nothing regressed;
     loop until clean.
   - **Quality gate (Step 6)** — the quality-gate commands from `.claude/project/project-context.md`, pasted evidence.
   **Gate the AC/plan verification (Step 7) purely on plan-doc existence** at
   `docs/superpowers/plans/<STORY-KEY>.md` — **not** on the head-branch name. Run Step 7 when that
   plan doc exists; otherwise skip it — the comments are the requirements. This single signal is
   correct for every path: feature-full (plan exists) → verify; feature-lightweight (no plan) → skip;
   defect (no plan) → skip — each for the right reason (no plan doc), not by an accidental
   `feat/`-branch-name match (which would wrongly skip a `fix/<KEY>` defect head and mis-handle any
   non-`feat/` feature head). Do **not** add an `OR WORK_KIND=feature` disjunct — it is redundant (a
   lightweight feature with no plan correctly skips on plan-absence alone) and would wrongly force
   plan verification when no plan exists. (On the defect path the QA playbook's regression-evidence
   contract runs in place of the plan checklist.)

5. **Close out the PR threads (only after fixes are pushed AND the gate is green).** For every
   triaged inline comment, post its justification back on the exact thread and resolve the
   accepted ones — so when the reviewer returns, only NON-accepted comments remain open, each
   carrying the reason it wasn't applied. Write the reply text to a file (never inline JSON), then
   call the helper per comment:
   ```bash
   dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)   # session-scoped ./.tmp/<key>
   # accepted — reply names the fix + commit, then the thread is RESOLVED:
   printf '✅ **Accepted** — %s\n\nFixed in %s.' "<why valid + what changed>" "<fix-commit-sha>" > "$dir/reply-<id>.md"
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-resolve-comment.sh <PR> <id> accepted "$dir/reply-<id>.md"
   # rejected — reply explains why it's not applied; thread is LEFT OPEN:
   printf '❎ **Not applied** — %s' "<why wrong/stale/out-of-scope in this app>" > "$dir/reply-<id>.md"
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-resolve-comment.sh <PR> <id> rejected "$dir/reply-<id>.md"
   ```
   - The helper replies in-thread (REST) and, for `accepted`, resolves the thread via the GraphQL
     `resolveReviewThread` mutation; `rejected` replies but leaves the thread open. It prints one
     `replied:` / `resolved:` / `left-open:` line per comment.
   - **Review-summary bodies and top-level issue comments are not resolvable threads** — for any
     of those you accepted/rejected, post ONE summarising PR issue comment instead
     (`gh pr comment <PR> --body-file "$dir/summary.md"`), listing each with its decision+reason.
   - **Commit-SHA target** (not a PR): there are no resolvable review threads — reply on the commit
     comment (`gh api .../commits/<SHA>/comments/<id>/replies`) with the justification; nothing to
     resolve.
   - Best-effort: a reply/resolve failure (deleted thread, permissions) must NOT fail the run —
     log it and continue; the code fixes are already pushed.

6. **Report** the verdict: per-comment decision table (accepted+resolved / rejected+left-open, each
   with its justification), fixes pushed, re-review rounds, and gate evidence. On `Status: blocked`,
   surface the reason — do not improvise.

**IMPORTANT:** This makes real code changes (fix commits pushed to the PR head branch). It does
NOT create a new PR. If the QA loop returns `Status: blocked`, STOP and surface it.

## Final action — release the session (required)

After everything above is complete (success, or a terminal STOP/blocked surfaced to the user), run
this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It signals the automation worker to release this session's slot. Outside the worker
(`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

GitHub PR number/URL or commit SHA:
$ARGUMENTS
