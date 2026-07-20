---
title: '/sdlc:prd'
description: 'Convert a Jira Epic into a full PRD. Creates branch, writes docs/features/ doc, raises PR, and links back to the Epic. Run after /refine-feature or Slack ideation.'
related-adrs: []
---

# /sdlc:prd

Convert a Jira Epic into a full PRD. Creates branch, writes docs/features/ doc, raises PR, and links back to the Epic. Run after /refine-feature or Slack ideation.

---

**Source:** `plugins/sdlc/commands/prd.md`

Dispatch the `product-manager` agent to produce a PRD from the Jira Epic.

The agent should:

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
6. Commit, push, and raise PR titled `docs(prd): <Epic summary>`
7. Comment the Epic with the PRD reference:
   ```bash
   acli jira workitem comment create --key <EPIC-KEY> \
     --body "PRD: docs/features/YYYY-MM-DD-<slug>.md | PR: <PR_URL>"
   ```
8. Return: Epic key, PRD file path, PR URL

## Final action — release the session (required)

After **everything above is complete** (success or a terminal stop), run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Jira Epic key (e.g. CER-100):
$ARGUMENTS
