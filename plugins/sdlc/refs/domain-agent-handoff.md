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

If either check fails → return immediately (full 5-line blocked shape — see Return format below):
`Status: blocked` / `Note: branch <BRANCH_PREFIX>/<STORY-KEY> not found — principal-engineer must push it before dispatching` / `Summary: aborted before work — branch missing` / `Skills loaded: none` / `Rules applied: none` (an early abort loads no skills and applies no rules, so `none` is correct for both).

## Branch and PR — do not create

The Principal Engineer has already created branch `<BRANCH_PREFIX>/<STORY-KEY>` on origin and will open the PR after all phases complete. Your responsibility is to add commits on this branch — nothing else.

## Context reuse

```text
path already read in full in this transcript -> never read it again
Edit/Write returned success -> no confirming read   # Edit/Write fail loudly; a read after a successful edit verifies nothing
earlier read was windowed AND another region is needed -> read ONLY the missing region with offset/limit
```

Carve-outs — a re-read here is correct, not a violation:

```text
a git op (checkout, merge --ff-only, fetch+reset) changed the tree since the read -> re-read
the earlier read was reported truncated -> re-read
the earlier read happened in a DIFFERENT transcript -> read normally   # a dispatched agent's context is empty; a ledger names paths, it never supplies their content
```

Precedence: correctness wins. Cannot establish the current content of a file you must edit -> read it. An unnecessary read is cheap; a wrong edit is not.

## Bounded reads

```text
you need a named symbol/string, not the whole file -> Grep/Glob for it FIRST, then Read with offset around the hit
file is over the threshold AND you are not executing it as instructions -> Read with limit; widen only if the window proves insufficient
threshold := ~400 lines (limit=400)   # 2,000 est tok ~= 7,400 bytes ~= 400 lines; Read's own default cap is 2,000 lines
```

Carve-outs — a whole-file read here is correct, not a violation:

```text
the file IS the instruction you must execute (a playbook, a ref, your dispatch's plan/spec section) -> read whole   # executed end-to-end, not searched
the file is under the threshold -> read whole   # 68.7% of candidate reads sit here; the window returns the file anyway, so the Grep is pure overhead
you are about to Edit it and must establish its current content -> read whole
```

Precedence: correctness wins. A missing-context failure costs a QA round; an unnecessary whole read costs bytes. When in doubt, read more.

## Memory write (before committing)

Memory is a set of small, self-describing rule files, not a diary. Collection at the start of your
dispatch (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-memory.sh <your-agent-name>`) already surfaced
every rule and ADR that binds you — this section is about what you write back, not what you read.

Captures staged this story aren't collected (`collect-memory.sh` only surfaces `status: active`) —
also run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/list-captured.sh --story <STORY-KEY> --kind rule --agent <your-agent-name>`
and read the returned paths yourself. Never paste rule text into a prompt — a path costs far less
than the content it points at.

```text
own-domain rule -> bash ${CLAUDE_PLUGIN_ROOT}/scripts/capture-learning.sh rule <your-name>/<rule-id> <STORY-KEY> [<body-file>]
cross-domain rule (binds more than one agent) -> capture-learning.sh rule shared/<rule-id> <STORY-KEY> <body-file>   # the body file's `agent:` lists every agent it binds
<rule-id> := kebab-case, MUST equal the capture's `id`
```

Prints `CAPTURED=<path>` into the gitignored staging area in the primary checkout. You never write
`.claude/memories/agents/**` directly — a file lands there only once a human promotes a capture
through `/sdlc:docs distill`.

**The 7-field schema** (YAML frontmatter, all fields required):

Artifact encoding contract: unpadded tables, no section dropped, one-line N/A, verbatim contracts, rationale as annotation, prose < 10 lines between headings. plugins/sdlc/refs/artifact-encoding.md

```yaml
---
id: <kebab-case, equals the filename stem, unique across .claude/memories/agents/**>
agent: [<agent-name>, ...] # exactly [<your-name>] under your own dir; length >= 2 under shared/
trigger: [<phrase>, ...] # 1-6 lowercase keyword phrases naming the situation this fires in
rule: When <condition>, <action>. # ONE line, <= 200 chars
evidence: [<Jira key | PR#n | 7-40 char SHA>, ...] # length >= 1
uses: 0 # incremented each dispatch that applied the rule
status: active # active | deprecated | promoted — only active is collected at dispatch
---
```

Body is optional — a single `## Why` section, <= 10 lines. It is never read during collection; open
it yourself only when the one-line `rule` isn't enough context.

A capture also carries `captured`, `story`, `origin`, `promote-target` — written by the script, not
you.

**Admission test.** Write a candidate rule file only if ALL four hold:

```text
ASSERT generalized — a condition + action that constrains future work, not a narrative of one story
ASSERT non-obvious — not already derivable from the agent definition, the project override, or a repo `CLAUDE.md`
ASSERT falsifiable trigger — you can name the concrete situation it fires in (populates `trigger`)
ASSERT not already an accepted ADR — no `status: accepted` ADR covers the same decision (T2 wins)
all four hold -> write the candidate rule file
any fail -> write nothing
```

Rejected by construction: story diaries, `Learnings`/`Pitfalls`/`Patterns` prose blocks, restatements
of existing config, and any entry that only makes sense with the originating story in mind.
**Skipping is normal, not a failure** — most dispatches write nothing new.

**Counter-only updates.**

```text
rule cited in `trigger` AND actually applied this dispatch (own, or a `shared/` one) -> capture-learning.sh rule <its dir>/<its id> <STORY-KEY> <body-file: `uses: 1`, `evidence: [<STORY-KEY>]`>   # promotion merges into the target's count
```

## Domain verification

Each domain has its own verification commands. Run **all** of them before considering work complete — listed in each agent's body and the directory CLAUDE.md files. See `.claude/project/project-context.md` for project-level quality gate commands.

## Commit your domain changes

Stage your specific files (do NOT use `git add .`):

```bash
git add <domain paths>
```

Then invoke the `conventional-commit` skill to construct and execute the commit message. Use the directory name as the scope — see `.claude/project/project-context.md` for valid scopes in this project.

**Do NOT push.** The Principal Engineer pushes `<BRANCH_PREFIX>/<STORY-KEY>` to origin after verifying your commits landed locally. Your job ends at commit.

## Return format

Return only these lines to the Principal Engineer (no other prose). The line count depends on status:

**Complete return — exactly 4 lines** (`Note:` omitted):

```
Status: complete
Summary: <one line — what files changed, key entities/handlers/screens touched>
Skills loaded: <comma-separated override skill names | none>
Rules applied: <rule-id>, <rule-id> | none
```

**Blocked return — exactly 5 lines** (`Note:` present):

```
Status: blocked
Note: <one line — why blocked>
Summary: <one line — what was attempted>
Skills loaded: <comma-separated override skill names | none>
Rules applied: <rule-id>, <rule-id> | none
```

- `Skills loaded:` is **required on every return** (complete, blocked, or early abort). An absent line is a contract violation.
- Its value lists every **runtime override (project) skill** you invoked/applied this dispatch (e.g. `tailwind-design-system, react-components`) — including any skill the dispatch prompt named that happens to also be one of your agent's own required first-turn skills (loaded via the Skill tool per your agent's "Required skills (load FIRST)" section, not frontmatter — frontmatter `skills:` preloads are re-injected in full on every SendMessage resume, harness bug anthropics/claude-code#76337, which is why NA-25 moved every generic skill to a first-turn Skill-tool load instead). For those, "invoked" means you applied it to the task; listing it is what satisfies the orchestrator's set-coverage check. Only omit a first-turn generic skill the dispatch prompt did **not** name — never pad the line with those.
- Emit the literal `none` only when no applicable override skill was loaded. Whether `none` is a pass or a failure is decided **mechanically against your dispatch prompt** by the orchestrator: `none` passes iff the dispatch prompt declared no applicable skills; if the prompt named skills, `none`/missing/empty/partial is a failure.
- If your dispatch prompt neither names skills nor declares none applicable, select the applicable skills from your override yourself, invoke them, and list them — `none` then means none were applicable to the task.
- `Rules applied:` is **required on every return**, same as `Skills loaded:`. Its value cites the rule
  `id`s (yours or `shared/`) that collection surfaced and that you actually followed this dispatch —
  the same set you incremented `uses` on. `none` is valid and expected whenever collection emitted
  nothing applicable; it is not a sign anything went wrong. An agent that applied a rule but omitted
  the line is a contract violation, handled exactly as a missing `Skills loaded:` line — the
  orchestrator re-dispatches.

Large outputs are dropped at the dispatch boundary — keep it to the 4 lines (complete) / 5 lines (blocked) above.

## Things you never do

- Never create a branch yourself. `<BRANCH_PREFIX>/<STORY-KEY>` already exists.
- Never open a PR. The Principal Engineer opens it after all phases pass.
- Never run any agent or skill from outside your declared domain — escalate by returning `Status: blocked` with a one-line note instead.
- Never update the package lockfile or modify dependency versions without explicit instruction.
- Never run cloud deploys — those are manual ops actions outside agent scope.

## Plan slice

```text
SLICE names a path -> Read it before Task 1; it is this phase's contract
unreadable | empty -> Status: blocked, Note: plan slice unreadable   # never improvise the phase
```
