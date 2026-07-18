---
description: Produce a technical design spec for a Jira story. Creates branch, writes docs/superpowers/specs/ doc, raises PR, and links back to the story. Run after /stories.
---

## Step 0 — Issue-type guard (defects skip spec)

Before dispatching anything, probe the issue type — **defects have no spec phase**. Use the canonical
one-liner (same as `/auto` Step 0):

```bash
ITYPE="$(acli jira workitem view <STORY-KEY> --fields issuetype --json 2>/dev/null \
           | jq -r '.fields.issuetype.name // empty' | tr '[:upper:]' '[:lower:]')"
```

If `ITYPE == bug` → **STOP** with: `defects skip spec/plan — run /impl`. Do **not** create a
`spec/<STORY-KEY>` branch and do **not** dispatch the agent. (This is defence-in-depth: the `/auto`
Step-0 entry gate + lightweight defect routing are the primary gate; this guards a human running
`/spec` directly on a Bug.) Otherwise continue.

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
   # Raise the PR atomically via raise-pr.sh (create + mark-ready + request @copilot + verify the
   # request attached). NEVER hand-roll gh pr create + add-reviewer separately — that is how the
   # reviewer step gets dropped. Write the body to the session-scoped temp dir, then pass by file.
   dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
   # write "$dir/pr-body.md" with your file-write tool, e.g.:
   #   Spec for <STORY-KEY>. See docs/superpowers/specs/<STORY-KEY>.md.
   PR_URL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/raise-pr.sh \
     "spec/<STORY-KEY>" develop "docs(spec): <STORY-KEY> <story summary>" "$dir/pr-body.md" --phase spec)
   ```
8. Comment the story with the spec reference. Use the real captured PR URL (must be a full `https://github.com/...` URL — not a placeholder):
   ```bash
   acli jira workitem comment create --key <STORY-KEY> \
     --body "Spec ready.
   File: docs/superpowers/specs/<STORY-KEY>.md
   PR: <PR_URL>"
   ```
9. Return: story key, spec file path, PR URL

## Final action — loop the PR to Copilot-clean, then release (when run standalone)

This step applies only when `/spec` is the **top-level** command. When `/auto` generates the spec as
part of Workflow A (it dispatches the `solutions-architect` agent for this work), `/auto` owns the
loop **and** the single session release at the very end — do **not** run this final action nested.

After **everything above is complete** (the spec PR is raised and the Jira comment posted), the
standalone command's final action is to drive the Copilot review-fix loop on the just-raised PR to
convergence, **then** release — the loop is the session's **tail**:

```bash
# PR_URL is the spec PR captured from the agent (step 9). Drive the review-fix loop on it.
/loop /sdlc:loop <PR_URL>
```

The native `/loop` re-invokes `sdlc:loop` each pass: it polls Copilot's review of the PR head, runs
`/review-fix` inline on each round of comments, and exits when the head is Copilot-reviewed with no
unresolved comments and checks pass (or it halts / hits the idle budget). Because the loop is the
**tail**, its own "Final action — release the session" emits the single `session-complete` — do
**NOT** call `session-complete.sh` separately here.

> - If the harness cannot invoke the native `/loop` from inside a command, drive `sdlc:loop`'s
>   pass-cycle via `ScheduleWakeup` instead (same effect — the loop is the last thing the session
>   does), then let its final pass release.
> - If the command hit a terminal STOP **before** a PR was raised (nothing to loop on), run
>   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` directly to release.

Jira story key (e.g. CER-123):
$ARGUMENTS
