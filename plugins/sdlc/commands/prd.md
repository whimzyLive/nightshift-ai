---
description: Optional — convert a Jira Epic into a full PRD. The product-manager drafts docs/features/ doc, then every open question is settled with you in this session before the PR is raised and linked back to the Epic. Run after /refine-feature and before /design; skip it when the Epic already says enough — /stories then decomposes from the Epic.
---

Two phases: the agent drafts and never commits; the questions are asked here, where the session can
pause for you (a subagent cannot).

## Step 1 — Draft (agent)

Dispatch the `product-manager` agent to draft the PRD from the Jira Epic. The agent should:

1. Read `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` and apply the protocol with `<KEY>=<EPIC-KEY>` from $ARGUMENTS
2. Extract summary, description, all comments, linked tickets, and attachments — use everything as the source of truth for the feature
3. Derive a kebab-case slug from the Epic summary (max 5 words)
4. Create and switch to branch `prd/<EPIC-KEY>` (e.g. `prd/CER-100`) — branch name carries the Epic key so the artifact is traceable from `git log` alone
5. Expand into a full PRD at `docs/features/YYYY-MM-DD-<slug>.md`:
   - User story (As a / I want / So that)
   - Acceptance criteria (5–10 binary, testable criteria)
   - User flows (happy path + edge cases step-by-step)
   - Out of scope (explicit boundaries)
   - Open questions (product decisions still needed)
   - Dependencies (features that must exist first)
   - Product checks: roles affected, mobile/offline required, surfaces (web/mobile/both)
   - Design & references: the Epic's design `index.md` path (its **Design** section or `Design:` comment; none yet → `Design: pending — /design <EPIC-KEY>`), **Dev Notes**, and **References**, carried verbatim — link them, never restate the design in prose
6. **Draft only.** Never commit, push, raise a PR, or write to Jira — leave the file uncommitted on
   the branch. Use `to-prd` for the PRD's structure only, never its publish step. Never ask the
   user anything — every question goes in the return.
7. Return: the PRD file path, then one block per open question, every product decision the PRD
   leaves open (none → `OPEN_QUESTIONS=none`). `OPTIONS` holds 2 or 3 options separated by ` | `,
   the recommended one first:
   ```text
   Q: <the question, one sentence>
   WHY: <what it changes in the PRD — which AC, flow, or scope line>
   OPTIONS: <recommended option> | <option> | <option>
   ```

## Step 2 — Settle the open questions with you

`SDLC_SESSION_KEY` set (unattended — nobody can answer) → skip to Step 3; the questions stay in
the PRD's Open questions and go on the Epic comment.

Otherwise ask every returned question with `AskUserQuestion` — at most 4 per call, in PRD order,
each option list as returned with the first labelled `(Recommended)`, plus `Leave open` last. Then
edit the PRD yourself:

```text
answered -> remove it from Open questions; add "- **<question>** — <answer>" under a
            `## Decisions` section (create it before Open questions); apply the answer to every
            AC, flow, and Out-of-scope line it changes
Other    -> the typed answer, recorded and applied the same way
Leave open -> stays in Open questions
an answer raises a new question -> ask it in the next call; stop after 2 follow-up rounds
```

## Step 3 — Commit, PR, link

`dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)`, then write `"$dir/pr-body.md"` with your
file-write tool: the Decisions, and any questions left open. The Epic comment's `<OPEN>` := empty,
or — unattended with questions left open — a newline and each open question, one per line, for the
Epic's author to answer. Then:

```bash
git add docs/features/YYYY-MM-DD-<slug>.md
git commit -m "docs(prd): <Epic summary>"
git push -u origin prd/<EPIC-KEY>
gh pr create --base <BASE-BRANCH> --title "docs(prd): <Epic summary>" --body-file "$dir/pr-body.md"   # <BASE-BRANCH> := `Base branch` row of .claude/project/project-context.md
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
acli jira workitem comment create --key <EPIC-KEY> \
  --body "PRD: docs/features/YYYY-MM-DD-<slug>.md | PR: <PR_URL> | Open questions: <N> resolved, <M> open<OPEN>"
```

## Step 4 — Return

Epic key, PRD file path, PR URL, each decision recorded, and any questions still open.

## Final action — release the session (required)

After **everything above is complete** (success or a terminal stop), run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Jira Epic key (e.g. CER-100):
$ARGUMENTS
