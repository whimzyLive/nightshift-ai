# QA alternative entry — external review feedback (`/review-fix`)

Loaded by `refs/qa-engineer-playbook.md` Step 1 **only on the `/review-fix` entry** — the `/auto`
and `/impl` paths never read it.

When findings come from an existing **GitHub PR or commit** (Copilot or human reviewers) rather
than a fresh code-reviewer pass, SKIP the Step 1 reviewer dispatch. Instead build the finding list from the
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
re-review is a fresh scoped reviewer over the **applied fix commits** (`BASE_SHA`=pre-fix HEAD,
`HEAD_SHA`=post-fix HEAD), confirming each accepted comment is resolved and nothing regressed; the
round cap and follow-up rules of `refs/qa-review-rounds.md` apply. On `Status: capped`, an accepted
comment still on `Open (capped):` gets its reply but its thread is NOT resolved.

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
