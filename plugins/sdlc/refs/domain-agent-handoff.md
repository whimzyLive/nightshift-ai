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

If either check fails → return immediately (full 4-line blocked shape — see Return format below):
`Status: blocked` / `Note: branch <BRANCH_PREFIX>/<STORY-KEY> not found — principal-engineer must push it before dispatching` / `Summary: aborted before work — branch missing` / `Skills loaded: none` (an early abort loads no skills, so `none` is correct).

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

Return only these lines to the Principal Engineer (no other prose). The line count depends on status:

**Complete return — exactly 3 lines** (`Note:` omitted):

```
Status: complete
Summary: <one line — what files changed, key entities/handlers/screens touched>
Skills loaded: <comma-separated override skill names | none>
```

**Blocked return — exactly 4 lines** (`Note:` present):

```
Status: blocked
Note: <one line — why blocked>
Summary: <one line — what was attempted>
Skills loaded: <comma-separated override skill names | none>
```

- `Skills loaded:` is **required on every return** (complete, blocked, or early abort). An absent line is a contract violation.
- Its value lists every **runtime override (project) skill** you invoked/applied this dispatch (e.g. `tailwind-design-system, react-components`) — including any skill the dispatch prompt named that happens to also be frontmatter-preloaded (for those, "invoked" means you applied it to the task; listing it is what satisfies the orchestrator's set-coverage check). Only omit a frontmatter-preloaded skill the dispatch prompt did **not** name — never pad the line with those.
- Emit the literal `none` only when no applicable override skill was loaded. Whether `none` is a pass or a failure is decided **mechanically against your dispatch prompt** by the orchestrator: `none` passes iff the dispatch prompt declared no applicable skills; if the prompt named skills, `none`/missing/empty/partial is a failure.
- If your dispatch prompt neither names skills nor declares none applicable, select the applicable skills from your override yourself, invoke them, and list them — `none` then means none were applicable to the task.

Large outputs are dropped at the dispatch boundary — keep it to the 3 lines (complete) / 4 lines (blocked) above.

## Things you never do

- Never create a branch yourself. `<BRANCH_PREFIX>/<STORY-KEY>` already exists.
- Never open a PR. The Principal Engineer opens it after all phases pass.
- Never run any agent or skill from outside your declared domain — escalate by returning `Status: blocked` with a one-line note instead.
- Never update the package lockfile or modify dependency versions without explicit instruction.
- Never run cloud deploys — those are manual ops actions outside agent scope.
