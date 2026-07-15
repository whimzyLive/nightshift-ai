# AI-Config Analyze Protocol

Shared scan/apply protocol for the `ai-enablement-engineer` agent and the `/sdlc:analyze` command.
Neither file duplicates this logic — both reference the anchor headings below. This ref exists so
the drift/gap rules, ownership resolution, and apply flow are defined exactly once.

## Ownership-resolution rules

**Runtime rule (verbatim):** effective write-scope = (config-driven AI-config surface ∪
table-assigned areas) − read-only carve-outs.

**Active (definition):** `ai-enablement-engineer` is Active in a repo if and only if the current
repo's workspace→agent table in `.claude/project/project-context.md` assigns at least one area to
it — row presence is the sole activity signal; no separate `Active: true`/opt-in flag exists
anywhere. Every "if not Active, STOP" gate in this agent/command's runtime path (First steps,
scan protocol, `/sdlc:analyze`) resolves against this one definition.

- **Config-driven AI-config surface** — the baseline globs below ship with the agent definition;
  a per-repo override may add more. This list is illustrative-but-comprehensive, never exhaustive,
  and never hard-coded into the resolution logic:
  - `CLAUDE.md` (root) and nested `**/CLAUDE.md`
  - `AGENT.md`, `AGENTS.md` (+ nested `**/AGENTS.md`)
  - `.agents/**` (incl. `.agents/skills/**`)
  - `.claude/**` (settings, skills, project agents, skills-lock) — minus the read-only carve-outs
  - `.github/copilot-instructions.md`
  - `.cursor/rules/**`, `.cursorrules`
  - `.windsurfrules`
  - `GEMINI.md`
  - `plugins/**`, `skills/**`
  - Plugin/skill metadata: `**/SKILL.md`, `**/.claude-plugin/plugin.json`,
    `.claude-plugin/marketplace.json`
- **Table-assigned areas** — whatever the current repo's workspace→agent table in
  `.claude/project/project-context.md` assigns to `ai-enablement-engineer` (e.g. `plugins/`,
  `skills/`). Read this at runtime; never hard-code an area path in the resolution logic itself
  (a path may appear only as an illustrative example above, never as the source of truth).
- **Read-only carve-outs** — never written, even when the agent is active:
  - `.claude/project/project-context.md` (source of ownership truth; rewriting it would be
    circular)
  - `.claude/.*-plugin-root` pointers (environment wiring written by init)
  - `.claude/memories/agents/<other-agent>.md` (each agent owns its own memory file; the two
    sanctioned exceptions — the human-arbitrated memory-conflict reset and the founder-gated
    distill deletion — are enumerated in
    [Memory-ownership exceptions](#memory-ownership-exceptions); both apply only as a reviewable
    diff/PR, never silently)

At the start of any run, print the resolved write-scope. Before any write, refuse and abort on a
path outside that scope (AC-5).

## Base branch

`<BASE-BRANCH>` is read from `.claude/project/project-context.md`'s Base branch token — never
assume the repo default (e.g. `main`), consistent with every other SDLC agent/command that branches
off a base. Used when creating the standalone `chore/ai-config-<slug>` branch in
[Apply flow](#apply-flow) step 2.

## Scan protocol

Read-only. Repo-wide read is always permitted; writes are scope-limited to the resolved
write-scope above.

1. Resolve write-scope per [Ownership-resolution rules](#ownership-resolution-rules) and print it.
2. If the agent is not Active in `.claude/project/project-context.md` — including a missing or
   malformed table, per [Active (definition)](#ownership-resolution-rules) — stop here and report
   per the [Error handling](#error-handling) row. Write nothing.
3. Run every check in the [Drift / gap table](#drift--gap-table) against the resolved scope
   (reads may range repo-wide; only writes are scope-limited).
4. Run [Memory-conflict analysis & resolution](#memory-conflict-analysis--resolution) as its own
   pass over the AI-config surface vs. agent-learning memory.
5. Emit the report using [Output shape](#output-shape). If nothing was found, report "no drift
   detected" and exit cleanly.

## Drift / gap table

| Check                                                                         | Drift/gap detected                                                                                                                                                                                                                                                                                                                                                      |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Skills on disk vs skills-lock (`.claude/project/skills.json` and/or lockfile) | Skill dir present but not in manifest, or manifest entry with no dir                                                                                                                                                                                                                                                                                                    |
| Agent overrides vs skills                                                     | Override lists a skill that resolves to no installed/bundled/project skill                                                                                                                                                                                                                                                                                              |
| Override directory guides vs disk                                             | Override references a `CLAUDE.md` guide that does not exist                                                                                                                                                                                                                                                                                                             |
| Dangling refs/scripts                                                         | A `refs/*.md` or `scripts/*` path referenced by an agent/command resolves to no file                                                                                                                                                                                                                                                                                    |
| Workspace→agent table vs disk                                                 | Table lists a path that no longer exists, or an area with no owner                                                                                                                                                                                                                                                                                                      |
| AI-config-file freshness                                                      | Documented structure in any owned AI-config convention diverges from disk                                                                                                                                                                                                                                                                                               |
| Plugin/skill metadata                                                         | `SKILL.md` missing required front-matter; `plugin.json`/`marketplace.json` referencing a missing plugin path                                                                                                                                                                                                                                                            |
| **Config-vs-memory semantic conflict**                                        | An owned AI-config file (`CLAUDE.md`/`AGENTS.md`/override/etc.) asserts one semantic while agent-learning memory (`.claude/memories/agents/*.md`, project shared memory) records a contradictory one — see [Memory-conflict analysis & resolution](#memory-conflict-analysis--resolution)                                                                               |
| Vendored-skill staleness (advisory)                                           | Recorded pinned ref (README) older than reachable upstream — advisory only; refresh is manual                                                                                                                                                                                                                                                                           |
| **Skill gaps (AC-6)**                                                         | For gaps, run `find-skills` to surface candidates (see [Skill usage guardrails](#skill-usage-guardrails)); if none fit, note `skill-creator` can scaffold one                                                                                                                                                                                                           |
| **Memory bloat (recommendation-only)**                                        | An agent memory file (`.claude/memories/agents/*.md`) or `.claude/memories/reviews/patterns.md` is oversized or carries repeated/duplicated learnings — the finding **recommends running `/sdlc:adr --distill`** to curate them into ADRs. Recommendation only: this check never triggers a write, never runs distill itself, and adds no apply path to `/sdlc:analyze` |

## Skill usage guardrails

`find-skills` is sanctioned for **surfacing/suggesting** skill-gap candidates only. **Never** run
its `npx skills add`/`npx skills update` (or any other install/update) commands during a scan or
apply — those run unpinned, unvetted third-party code at install time, a supply-chain risk this
plugin does not accept implicitly. Any skill that should actually be installed goes through the
normal human-confirmed vet-and-pin vendoring flow (clone at a pinned ref, vet bundled
scripts/network calls, carry the license, record provenance in `plugins/sdlc/README.md`) — the same
process `skill-creator` and `find-skills` themselves were vendored through. `find-skills`'s own
`SKILL.md` (vendored verbatim from upstream) is not edited to add this constraint — it is enforced
here, in the agent's own usage of the skill, not in the vendored skill's instructions.

## Memory-ownership exceptions

Each agent owns its own memory file (`.claude/memories/agents/<name>.md`); writing another
agent's memory file is refused by default (see the read-only carve-outs above). Exactly two
documented, human/founder-gated exceptions are sanctioned — never a silent write, always a
reviewable diff/PR:

- **Exception 1 — human-arbitrated memory-conflict reset.** During
  [Memory-conflict analysis & resolution](#memory-conflict-analysis--resolution), when the human
  picks a source of truth and the wrong side is another agent's memory, `ai-enablement-engineer`
  may reset it to match — applied only as a reviewable diff/PR (or under explicit human
  instruction), never silently.
- **Exception 2 — founder-gated distill deletion.** `knowledge-engineer`, running `/sdlc:adr
--distill`, may delete promoted raw learning entries from any agent's memory file
  (`.claude/memories/agents/*.md`, `shared.md` subject to the audience-preservation rule in
  `${CLAUDE_PLUGIN_ROOT}/refs/adr-pipeline.md`, and `.claude/memories/reviews/patterns.md` — a
  distill evidence source per `adr-pipeline.md` §4 whose promoted-and-deleted entries `qa-engineer`
  reads back via the ADR that replaces them) — **only** as a reviewable diff/PR, **only** after
  the founder-confirmation gate approved the specific deletions (the phase-1 deletion list from
  `adr-pipeline.md`), and **only** subject to the `shared.md` audience-preservation rule. Like
  Exception 1, this is never a silent write.

No other cross-agent memory write is sanctioned; any reset or deletion outside these two named
exceptions is refused per [Error handling](#error-handling).

## Memory-conflict analysis & resolution

Detects where an owned AI-config file asserts one semantic while agent-learning memory
(`.claude/memories/agents/*.md`, project shared memory) records a contradictory one. Neither side
is presumed correct.

**Report format:** conflicts appear in their own section of the analyze report — one entry per
conflict listing the two (or more) contradictory sources, their exact contradictory assertions,
and each source's file path.

**Interactive resolution flow (human-arbitrated, never silent):**

1. Present the conflict and the candidate sources of truth; the human picks which side is correct
   (config vs. memory, or a specific file), or defers.
2. Reset the wrong side to match the chosen source of truth:
   - Wrong side is an owned AI-config file (`CLAUDE.md`/`AGENTS.md`/override/…) → edit it via the
     normal [Apply flow](#apply-flow) (reviewable diff/PR).
   - Wrong side is the agent's **own** memory (`.claude/memories/agents/ai-enablement-engineer.md`
     or project shared memory it owns) → edit it via the same reviewable flow.
   - Wrong side is **another agent's** memory → **Exception 1** in
     [Memory-ownership exceptions](#memory-ownership-exceptions): apply the human-confirmed reset
     as a reviewable diff/PR (or under explicit human instruction) — never a silent write.
3. No human decision (deferred) → report only; reset nothing.

## Apply flow

Applying any fix is explicit and always produces a reviewable diff — never a silent write, and
never without human confirmation.

0. **Human confirmation gate** — apply only a fix the human has explicitly confirmed from the
   report. No inline auto-apply path. **Dispatched mode:** when dispatched by `principal-engineer`
   on a story, the human-approved story/plan task _is_ the confirmation for the edits that task
   names — the interactive gate governs `/sdlc:analyze`-originated fixes; memory-conflict resets
   stay human-arbitrated in every mode.
1. **Scope guard** — resolve effective write-scope (per
   [Ownership-resolution rules](#ownership-resolution-rules)); if the fix's target paths are not
   all within scope (respecting the read-only carve-outs, and the memory-conflict exception only
   when human-arbitrated), **refuse and abort** with the offending path listed (AC-5).
2. **Branch (standalone mode only, BEFORE any edit):** running standalone via `/sdlc:analyze`,
   create and check out `chore/ai-config-<slug>` off `<BASE-BRANCH>` (per [Base branch](#base-branch)
   — never assume `main`), so the coming edits land on the fix branch, not whatever branch happened
   to be checked out. **Dispatched mode does not branch here** — commits land on the
   already-checked-out impl branch per `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`.
3. Apply the scoped edits (Edit/Write) only within resolved write-scope; for "create a missing
   skill", drive it through `skill-creator`.
4. Commit via the `conventional-commit` skill.
5. **Reviewable diff:**
   - **Dispatched by `principal-engineer`:** commit on the impl branch per
     `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`; `principal-engineer` opens the PR — do
     not self-raise.
   - **Standalone via `/sdlc:analyze`:** push the `chore/ai-config-<slug>` branch created in step 2,
     then raise a PR via
     `${CLAUDE_PLUGIN_ROOT}/scripts/raise-pr.sh <head> <BASE-BRANCH> "<title>" <body-file>`. The PR
     **is** the reviewable diff.
6. Report the diff/PR back to the user. Do not merge.

## Output shape

Per finding, report exactly these fields:

| Field            | Description                                                                         |
| ---------------- | ----------------------------------------------------------------------------------- |
| `area`           | The AI-config surface area or table-assigned area the finding belongs to            |
| `kind`           | One of `drift`, `gap`, or `conflict`                                                |
| `detail`         | What was found and why it's a finding                                               |
| `proposed fix`   | The concrete edit that would resolve it                                             |
| `target path(s)` | Each path flagged `W` (inside resolved write-scope) or `R` (read-only/scanned only) |

The **memory bloat** row's finding is always `kind: gap`, and its `proposed fix` is exactly
"run `/sdlc:adr --distill` to curate these learnings into ADRs" — a recommendation, never an
apply-able edit; its `target path(s)` are flagged `R` (report-only, never written by this scan).

No writes happen in scan mode — every listed target path is informational until a human confirms
an apply via the [Apply flow](#apply-flow).

## Error handling

Canonical error-handling table for both the `ai-enablement-engineer` agent and the `/sdlc:analyze`
command — defined exactly once here; each references this anchor instead of restating the rows.

| Scenario                                                                                                                                        | Behavior                                                                                                                                      |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Repo not opted in / `project-context.md` missing or malformed table (agent not Active — see [Active (definition)](#ownership-resolution-rules)) | **STOP** — report-only: "repo not opted in or project-context unreadable — run `/sdlc:init`." Write nothing. Do not scan.                     |
| Scan finds no drift/gaps/conflicts                                                                                                              | Report "no drift detected" and exit cleanly.                                                                                                  |
| Apply attempted without human confirmation                                                                                                      | Refuse — confirmation is mandatory (never auto-apply).                                                                                        |
| Apply target outside resolved write-scope                                                                                                       | Refuse and abort; print the offending path(s); make no writes (AC-5).                                                                         |
| Memory conflict with no human decision (deferred)                                                                                               | Report only; reset nothing.                                                                                                                   |
| Cross-agent memory write attempted outside the two named exceptions (see [Memory-ownership exceptions](#memory-ownership-exceptions))           | Refuse — a reset must be human-arbitrated (Exception 1) and a distill deletion must be founder-gated (Exception 2); anything else is refused. |
| `find-skills` / `skill-creator` unavailable or offline                                                                                          | Degrade gracefully — skip the skill-suggestion step, still emit structural drift; note the skip.                                              |
| `find-skills` install/update commands would run                                                                                                 | Refuse — see [Skill usage guardrails](#skill-usage-guardrails); surfacing/suggesting only.                                                    |
| `raise-pr.sh` fails during standalone apply                                                                                                     | Surface the failure; leave branch + local commit for manual recovery; do not retry silently.                                                  |
