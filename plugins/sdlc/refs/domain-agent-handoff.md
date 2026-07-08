# Domain-agent handoff protocol

Shared completion protocol for domain engineers dispatched by `principal-engineer`. Referenced from `database-administrator`, `platform-engineer`, `ai-enablement-engineer`, `sync-engineer`, `web-engineer`, `mobile-engineer`. Replaces the duplicated "Branch & PR" + "Completion checklist" + "Write memory" block previously inlined in each.

## Pre-work: verify and checkout branch — BEFORE reading or writing any file

> **`<BRANCH_PREFIX>/<STORY-KEY>` is the impl branch the orchestrator named in your dispatch
> prompt** — `fix/<STORY-KEY>` for a defect (`WORK_KIND=defect`), `feat/<STORY-KEY>` for a feature.
> Use the exact branch name the orchestrator gave you; do **not** assume `feat/`.

```bash
git fetch origin
git checkout <BRANCH_PREFIX>/<STORY-KEY> 2>/dev/null \
  || { echo "STOP: <BRANCH_PREFIX>/<STORY-KEY> not found on origin — is principal-engineer dispatching correctly?"; exit 1; }
[ "$(git branch --show-current)" = "<BRANCH_PREFIX>/<STORY-KEY>" ] \
  || { echo "STOP: checkout failed — on $(git branch --show-current) instead of <BRANCH_PREFIX>/<STORY-KEY>"; exit 1; }
```

If either check fails → return immediately: `Status: blocked` / `Note: branch <BRANCH_PREFIX>/<STORY-KEY> not found — principal-engineer must push it before dispatching`.

## Branch and PR — do not create

The Principal Engineer has already created branch `<BRANCH_PREFIX>/<STORY-KEY>` on origin and will open the PR after all phases complete. Your responsibility is to add commits on this branch — nothing else.

## Memory write (before committing)

Append non-obvious learnings to your agent memory file at `.claude/memories/agents/<your-name>.md`:

```
## YYYY-MM-DD — Story <STORY-KEY> — one-line summary
**Learnings:** <what worked or was discovered>
**Pitfalls:** <what went wrong or nearly went wrong>
**Patterns:** <reusable patterns confirmed>
```

If nothing non-obvious happened, skip the append — but still stage the file in case another agent earlier in the story updated it.

For cross-cutting findings (relevant to more than one domain), append to `.claude/memories/agents/shared.md` instead.

## Domain verification

Each domain has its own verification commands. Run **all** of them before considering work complete — listed in each agent's body and the directory CLAUDE.md files. See `.claude/project/project-context.md` for project-level quality gate commands.

## Commit the memory file alongside your domain changes

Stage your specific files and the memory file (do NOT use `git add .`):

```bash
git add <domain paths> .claude/memories/agents/<your-name>.md
```

Then invoke the `conventional-commit` skill to construct and execute the commit message. Use the directory name as the scope — see `.claude/project/project-context.md` for valid scopes in this project.

Do not split memory updates into a separate commit — they belong with the work that produced them.

**Do NOT push.** The Principal Engineer pushes `<BRANCH_PREFIX>/<STORY-KEY>` to origin after verifying your commits landed locally. Your job ends at commit.

## Return format

Return exactly three lines to the Principal Engineer (no other prose):

```
Status: complete|blocked
Note: <one line if blocked, else omit>
Summary: <one line — what files changed, key entities/handlers/screens touched>
```

Large outputs are dropped at the dispatch boundary — keep it to the three lines above.

## Things you never do

- Never create a branch yourself. `<BRANCH_PREFIX>/<STORY-KEY>` already exists.
- Never open a PR. The Principal Engineer opens it after all phases pass.
- Never run any agent or skill from outside your declared domain — escalate by returning `Status: blocked` with a one-line note instead.
- Never update the package lockfile or modify dependency versions without explicit instruction.
- Never run cloud deploys — those are manual ops actions outside agent scope.
