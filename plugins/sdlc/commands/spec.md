---
description: Produce a technical design spec for a Jira story. Creates branch, writes docs/superpowers/specs/ doc, raises PR, and links back to the story. Run after /stories.
---

Dispatch the `solutions-architect` agent to produce a technical spec for the Jira story.

The agent should:
1. Read `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` and apply the protocol with `<KEY>=<STORY-KEY>` from $ARGUMENTS
2. Find the parent Epic key from the story view JSON, then apply the same protocol with `<KEY>=<EPIC-KEY>` — Epic Jira description and comments are the product context; do not read any feature file from the repository
3. Read the existing code relevant to the story in the workspaces owned by the **Active** agents listed in `.claude/project/project-context.md` (use that file's workspace→agent table to locate them). Do not assume any specific framework path.
4. Create and switch to branch `spec/<STORY-KEY>`
5. Produce a complete tech spec. The writing-specs skill at `.agents/skills/writing-specs/SKILL.md` determines the file name and output location. Do NOT read `${CLAUDE_PLUGIN_ROOT}/commands/writing-specs.md` — that path does not exist.
   - Data model: new entities, modified entities, relationships (1:1, 1:N, M:N explicit)
   - API surface: endpoints, request/response TypeScript interfaces, permissions per role
   - Implementation guide per active backend workspace: module/stack file, handler/route structure, application layer (follow the relevant domain override + directory CLAUDE.md)
   - Web UI section (only if the project has an active web app and the story is web-scoped): pages, components, data hooks, client-state changes
   - Mobile UI section (only if the project has an active mobile app and the story is mobile-scoped): screens, offline read hooks, transaction builders needed
   - Offline-sync section (only if the project has an active sync layer and offline writes are required): sync-rule addition, bucket definition, user-scoping filter
   - Error handling and out-of-scope boundaries
6. Self-review before saving:
   - No TBDs — every open question has a concrete answer or flagged decision with suggested default
   - Every endpoint has a permission row
   - Every offline-write entity has a corresponding offline-sync section
   - Agent boundaries clear — spec says WHAT, not HOW line-by-line
7. Commit the spec file, push the branch to remote, then raise PR:
   ```bash
   # Stage and commit
   git add <spec-file-path>
   git commit -m "docs(spec): <STORY-KEY> <story summary>"
   # Push BEFORE creating PR — PR creation fails if branch not on remote
   git push -u origin spec/<STORY-KEY>
   # Then create PR and immediately mark ready for review (never draft)
   PR_URL=$(gh pr create --title "docs(spec): <STORY-KEY> <story summary>" --base develop --head spec/<STORY-KEY>)
   gh pr ready "$PR_URL"
   # Best-effort: request a Copilot review on the PR. Never fails the flow (needs gh >= 2.88.0 + Copilot review on plan).
   gh pr edit "$PR_URL" --add-reviewer "@copilot" || echo "warn: @copilot reviewer not assigned — PR created regardless"
   ```
8. Comment the story with the spec reference. Use the real captured PR URL (must be a full `https://github.com/...` URL — not a placeholder):
   ```bash
   acli jira workitem comment create --key <STORY-KEY> \
     --body "Spec ready.

File: docs/superpowers/specs/<STORY-KEY>.md
PR: <PR_URL>"
   ```
9. Return: story key, spec file path, PR URL

## Final action — release the session (required)

After **everything above is complete** (success or a terminal stop), run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`JUGAAD_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Jira story key (e.g. CER-123):
$ARGUMENTS
