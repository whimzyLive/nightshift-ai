---
description: Produce an implementation plan for a Jira story. Creates branch, writes docs/superpowers/plans/ doc, raises PR, and links back to the story. Run after /spec PR is reviewed and merged.
---

Dispatch the `tech-lead` agent to produce an implementation plan for the Jira story.

The agent should:
1. Derive the spec path: `docs/superpowers/specs/<STORY-KEY>.md` — no Jira comment lookup needed
2. Verify the spec file exists (must be merged to develop); if missing, STOP and tell user to run `/spec <STORY-KEY>` first
3. Read the spec file at the derived path
4. Fetch Jira story using `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` with `<KEY>=<STORY-KEY>` for story summary and Epic context
5. Read CLAUDE.md to verify stack assumptions
6. Create and switch to branch `plan/<STORY-KEY>`
7. Break the spec into concrete, ordered, agent-tagged tasks saved to `docs/superpowers/plans/<STORY-KEY>.md`:
   - Phase 1 — `database-administrator` (schema + entities + migrations — ALWAYS FIRST)
   - Phase 2 — `platform-engineer` (backend infra + handlers + config)
   - Phase 3 — `sync-engineer` (only if spec has an offline-sync section)
   - Phase 4 — `web-engineer` (only if spec has Web UI section)
   - Phase 5 — `mobile-engineer` (only if spec has Mobile UI section)
   - All phases sequential — principal-engineer dispatches one agent at a time
8. Each task must be completable without questions — include entity names, field names, route paths from spec
9. End each phase with a verification step (typecheck + lint + validate)
10. Commit the plan file, push the branch to remote, then raise PR:
    ```bash
    # Stage and commit
    git add <plan-file-path>
    git commit -m "docs(plan): <STORY-KEY> <story summary>"
    # Push BEFORE creating PR — PR creation fails if branch not on remote
    git push -u origin plan/<STORY-KEY>
    # Raise the PR atomically via raise-pr.sh (create + mark-ready + request @copilot + verify the
    # request attached). NEVER hand-roll gh pr create + add-reviewer separately — that is how the
    # reviewer step gets dropped. Write the body to the session-scoped temp dir, then pass by file.
    dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
    # write "$dir/pr-body.md" with your file-write tool, e.g.:
    #   Plan for <STORY-KEY>. See docs/superpowers/plans/<STORY-KEY>.md.
    PR_URL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/raise-pr.sh \
      "plan/<STORY-KEY>" develop "docs(plan): <STORY-KEY> <story summary>" "$dir/pr-body.md")
    ```
11. Comment the story. Use the real captured PR URL (must be a full `https://github.com/...` URL — not a placeholder):
    ```bash
    acli jira workitem comment create --key <STORY-KEY> \
      --body "Plan ready.

File: docs/superpowers/plans/<STORY-KEY>.md
PR: <PR_URL>"
    ```
12. Return: story key, plan file path, PR URL

## Final action — release the session (required)

After **everything above is complete** (success or a terminal stop), run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Jira story key (e.g. CER-123):
$ARGUMENTS
