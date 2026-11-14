# sdlc — repo-agnostic SDLC plugin

Generic SDLC agent workflow for Claude Code. Drives Jira → spec → impl → review
using a per-repo config file the consumer supplies at `.claude/project/project-context.md`.

`/auto` triages by complexity first: **small stories** (≤ the configurable lightweight threshold,
default 3 points) skip the spec and go **straight to implementation** (tasks derived inline from the
ticket). Larger stories get a spec written in your session — open questions asked, your approval
required — and the spec ships with the code in **one** PR; the spec's task list replaces a separate
plan. An epic gets every needed spec approved up front, then runs unattended. In-session review,
quality gate and AC check run in parallel; Copilot review on the PR is advisory.

## Install

    /plugin marketplace add <path-or-git-url-to-this-repo>
    /plugin install sdlc@nightshift

## Consumer repo requirements

- `.claude/project/project-context.md` — project constants (auto-loaded each session by this
  plugin's SessionStart hook).
- `.claude/project/agents/<domain>.md` — optional per-domain override bindings.
- Add `.claude/.sdlc-plugin-root` to the repo's `.gitignore` (see below).

## Plugin-path resolution (`.claude/.sdlc-plugin-root`)

`${CLAUDE_PLUGIN_ROOT}` is only available to Claude Code hooks and slash commands — it is **not**
injected into subagents. Since the SDLC agents must read bundled refs and run bundled scripts,
the SessionStart hook (which does have the variable) writes the resolved absolute plugin root to
`.claude/.sdlc-plugin-root` in the consumer repo each session. Every agent reads that one-line
marker from cwd and substitutes it wherever its instructions reference `${CLAUDE_PLUGIN_ROOT}`.
The file is a regenerated per-session cache — **gitignore it**.

## Dependencies

- **superpowers plugin** — **auto-installed.** Declared as a cross-marketplace dependency
  (`superpowers@claude-plugins-official`), so `/plugin install sdlc@nightshift` reuses an existing
  superpowers install or pulls it from the official marketplace. Agents invoke its skills:
  verification-before-completion, requesting-code-review,
  receiving-code-review, writing-plans — the domain agents, reviewer and verifier subagents load
  them. The orchestrating PE/QA playbooks load none: they carry their own dispatch and triage rules.
- **claude-mem plugin** — **auto-installed.** Declared as a cross-marketplace dependency
  (`claude-mem@thedotmack`). The `knowledge-engineer` agent's `/sdlc:docs distill` mode uses its
  `observation_search` / `get_observations` MCP tools to mine claude-mem's persistent cross-session
  observations as distill evidence; `seed adr` mode does not need it. If the tools are unavailable
  at runtime, distill halts with a clear message (see `refs/adr-pipeline.md`) — `seed adr` mode is
  unaffected.
- **CLIs (install manually — not plugins):** `acli` (Jira), `gh` (GitHub).

## `ai-enablement-engineer` — AI workflow manager agent

A domain agent, `plugins/sdlc/agents/ai-enablement-engineer.md`, that owns and keeps the
consumer repo's AI-configuration surface synchronized: `CLAUDE.md`/`**/CLAUDE.md`,
`AGENT.md`/`AGENTS.md`/`**/AGENTS.md`, `.agents/**`, `.claude/**`, `.github/copilot-instructions.md`,
`.cursor/rules/**`/`.cursorrules`, `.windsurfrules`, `GEMINI.md`, plus `plugins/**`/`skills/**` and
plugin/skill metadata (`**/SKILL.md`, `**/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`)
— minus a small set of read-only carve-outs (`.claude/project/project-context.md`,
`.claude/.*-plugin-root` pointers, other agents' memory files).

**Ownership is granted per-repo, at `/sdlc:init` time, via opt-in** — not by default. A repo that
opts in gets: workspace→agent rows granting `ai-enablement-engineer` ownership of `plugins/` and
`skills/`, the agent marked Active (row presence is the sole activity signal — no separate flag), and
a scaffolded override `.claude/project/agents/ai-enablement-engineer.md`. A repo that does not opt in
leaves the agent inactive with no effect; `platform-engineer`'s default owned paths no longer include
any AI-config path.

**Documented write-scope (AC-5):** effective write-scope = (config-driven AI-config surface ∪
table-assigned areas) − read-only carve-outs, resolved at runtime from the consumer repo's
workspace→agent table — never hard-coded. See `plugins/sdlc/refs/analyze-protocol.md` for the full
rule, the drift/gap checks, the memory-conflict analysis, and the apply flow. At the start of any run
the agent prints its resolved write-scope; before any write it refuses and aborts on a path outside
that scope.

## `knowledge-engineer` — ADR curation agent

A real-role domain agent, `plugins/sdlc/agents/knowledge-engineer.md`, that owns Architecture
Decision Record curation under `docs/adr/**`. Runs behind `/sdlc:docs` in two modes — **seed adr**
(formalize a founder-known pattern inline from `"<pattern>"`) and **distill** (mine the
accumulated learnings corpus for promotable candidates) — through one shared draft →
propose-tags → founder-confirm → write → regenerate-index → commit/PR pipeline defined once in
`refs/adr-pipeline.md`. It also owns the founder-gated deletion of promoted raw learning entries
from `<memory-root>/**` during a distill PR, sanctioned as Exception 2 in
`analyze-protocol.md`'s memory-ownership rules. Domain agents (and `qa-engineer`) read their own
section of the deterministically-regenerated `docs/adr/index.md` instead of re-deriving
conventions or re-appending a learning an accepted ADR already covers.

## `/sdlc:docs seed adr` / `/sdlc:docs distill` — Architecture Decision Records

`plugins/sdlc/commands/docs.md` routes ADR curation to `knowledge-engineer` across two phases split
by a founder-confirmation gate that lives at the command layer (a dispatched subagent cannot pause
for interactive input): phase 1 drafts candidate ADR(s) and returns without writing; the command
presents each draft, its proposed `agents:` tags, and (distill only) the exact rule entries slated
for promotion, then waits for explicit founder confirmation; phase 2 writes only the confirmed
items — assigns the next `NNNN`, writes `docs/adr/NNNN-slug.md`, regenerates `docs/adr/index.md`
deterministically from ADR frontmatter, and self-raises the PR. `knowledge-engineer` writes the
ADR only — the confirmed rule entries' `status: promoted` flip and eventual deletion are reassigned
to the `ai-enablement-engineer` maintenance op (`refs/memory-maintenance.md`), not done in the
ADR-authoring PR. `/sdlc:docs seed adr "<pattern>"` seeds inline with no corpus read;
`/sdlc:docs distill ["<focus>"]` consumes the maintenance op's mechanically-nominated rule
candidate list plus per-round review files (`<memory-root>/reviews/*.md`), PR review threads,
commit history, and claude-mem observations, promoting a candidate only on recurrence, cross-agent
relevance, or durable convention. Both are special routes on `/sdlc:docs` — `seed adr` branches
before the generic seed machinery and `distill` is not a member of the four generic doc-generation
modes (`sync`/
`release`/`seed`/`audit`), which this README does not otherwise document here. See
`refs/adr-pipeline.md` for the full pipeline and `skills/writing-adrs/SKILL.md` for the ADR
body/lifecycle/frontmatter contract it renders against.

## Skills: point-of-use loading

No agent loads skills upfront. `.claude/project/skills.json` (schema v2, `refs/skills-manifest.md`)
says which skills exist, which agents use them and when; the plugin ships its own contract rows in
`refs/skills-contract.json` (the skills its templates and gates depend on), merged under the repo's
rows by name, repo wins. `scripts/skills-for.sh <agent> [--mode <m>] [--paths <globs>] --print-prompt`
resolves the rows for a dispatch and prints the block the playbooks and commands paste into the
prompt: each skill with the step at which the agent invokes it, never earlier. A repo override no
longer lists skills.

Returns are verified by artefact, not by load: the spec against the writing-specs template
(`scripts/check-spec.sh`, run by `/spec` before approval and by the principal playbook when it reads
the spec), the plan against the tech-lead template (`scripts/check-plan.sh`, run by `/plan`), and each
phase's commit subjects against the conventional format (`scripts/check-commits.sh`, run in the
principal playbook Step 5). `Skills loaded:` stays on every return as information; no return passes or
fails on it. The `Rules applied:` line is still checked. See `plugins/sdlc/refs/principal-engineer-playbook.md`
(Steps 2, 4-5) and `plugins/sdlc/refs/qa-engineer-playbook.md` (Step 3).

### Upgrading a consumer repo

1. Update the plugin, then re-run `/sdlc:init`. On a v1 `skills.json` it infers each row's `agents` from the
   overrides' `## Project skills`, prints the rows for confirmation, writes v2, and removes those sections
   from the overrides.
2. Narrow a row with `when` (`paths`, `mode`, `step`) where a skill only applies to part of the repo.
3. Run `bash plugins/sdlc/scripts/skills-for.sh <agent> --print-prompt` to see what a dispatch will name.
4. Until step 1, a v1 file injects nothing and `skills-for.sh` warns; the plugin's contract rows still apply.

## `designer` and `/sdlc:design` — library-first design workflow

The `designer` agent (`agents/designer.md`) turns a UI Epic into screens built from components that
already exist. `/sdlc:design <EPIC> --draft | --plan | --final` runs it per mode; the command, not the
agent, publishes to the design canvas, asks the human gates and raises the PR.

- `--draft` — Balsamiq-style wireframe boards from the kit in `refs/wireframe-kit/`: one linked, playable board per screen in journey order (web, phone or both per `Wireframe targets`), every structural block tagged `data-pattern` with a pattern name or `?`. Built in the session temp dir, never the repo; the canvas is the only copy (the temp dir is deleted after publish, kept only with no canvas) and another pass starts from a fresh download; `scripts/wireframe-build.sh` assembles the pages, `scripts/wireframe-check.sh` lints them. Never ingested, no story may name one.
- `--plan` — `docs/design/<slug>/component-plan.md` (surface, pattern, template, component, reuse/extend/new, explore, story), the two tests before a `?` becomes new, and one library story per new or extended component. A control audit checks every control and list row the drafts draw against the bundle and the library (`scripts/library-exports.sh`, the plan's `Controls checked` table); anything that is not a clean reuse is a question for the user, and an "export an existing component" answer raises a library story too. It also creates the Epic's one `Design` story (`scripts/design-story.sh ensure --plan`), blocked by every library story; a re-run reuses it.
- `--final` — runs only when `scripts/library-blockers.sh` lists no open library story; screen boards mounted only from the design bundle, then the existing ingest (the plain `/sdlc:design <KEY> <files>` form is kept). The ingest refuses a draft board and a final board with no template, and lists board kinds in a `## Boards` table of `index.md`.
- `/sdlc:ui-audit [<EPIC>]` — Sonnet scan of the repo's UI paths for patterns built twice, display logic in pages, restyled shared components and pages off a template; proposes library stories, creates none unconfirmed. Suggested at the end of an epic run.
- The default order is library stories, `--final`, then `/sdlc:stories` last. `/sdlc:stories` links every UI screen story to the `Design` story: one that is still open blocks them until a person closes it once `/sdlc:design <EPIC> --final` has merged, one that is already Done holds nothing. `/sdlc:auto`, `/sdlc:impl` and `/sdlc:run` refuse a story it still blocks (`scripts/dep-gate.sh`); backend stories and Bugs are not held.
- Epic runs gain a design preflight (E0c): a UI child whose Design row names a draft, or whose library story is not Done, stops the run before any spawn. An open Design story holds only the stories it blocks.
- Specs gain a `## Reuse` section, stories a `UI surfaces` section, and QA flags duplicated or restyled shared components.

Principles, board kinds and gates: `refs/design-workflow.md`; plan format: `refs/component-plan.md`.
Repo values live in an optional `## Design` section of `project-context.md` (`Pattern vocabulary`,
`Bundle inventory`, `Bundle global`, `Wireframe targets`, `Final page prefix`,
`Component review`, `Library label`, `Design canvas`, `Publish recipe`, `Designer model draft|plan|final`)
and in `.claude/project/agents/designer.md`, which `/sdlc:init` scaffolds for a repo with a UI.

## `/sdlc:run` — background story runs

`/sdlc:run <KEY> [<KEY> ...] [--max N]` runs each story as its own background `claude --bg` session
(`/sdlc:auto` inside), skips a story whose blockers are not Done (naming an open Design story as the reason), staggers the starts, and arms a
10-minute session-local monitor tick that push-notifies when a run needs a person, stalls, or finishes.
`scripts/run-bg.sh KEY [note] [session-id]` starts or resumes one run; per-repo settings go in the optional
`.claude/project/bg-run.env`. `scripts/bg-status.sh KEY...` prints one line per story with a verdict
(`RUNNING`, `NEEDS_HUMAN`, `STALLED`, `DONE`, `NO_SESSION`) taken from the transcript, the PR and Jira, not
from the session state. A run that must stop for a decision opens a draft PR with a `Needs a human`
section and ends with `NEEDS YOU:`. Concurrency guidance, ordering, resume and the monitor prompt:
`plugins/sdlc/refs/bg-runs.md`.

## `/sdlc:analyze` — manual AI-config drift/gap scan

`plugins/sdlc/commands/analyze.md` dispatches `ai-enablement-engineer` for a **manual-only** repo-wide
scan (no scheduling/background trigger). Default mode is **read-only**: it reports drift, gaps, and
config-vs-memory semantic conflicts across the resolved write-scope (optionally narrowed via
`$ARGUMENTS`). Applying a proposed fix happens **only after explicit human confirmation** — never
auto-apply — and always produces a reviewable diff: a commit on the impl branch (with the PR opened
by `principal-engineer`) when dispatched on a story, or a self-raised PR on a `chore/ai-config-<slug>`
branch when run standalone.

## Bundled default skills (vendored)

`find-skills` ships **vendored** into `plugins/sdlc/skills/find-skills/` (same layout as every other
skill under `plugins/sdlc/skills/`) rather than as a marketplace dependency, because it originates
from [skills.sh](https://www.skills.sh) — a skills registry, not a Claude plugin marketplace.
`skill-creator` is not bundled: Claude Code ships it as `anthropic-skills:skill-creator`, and the
contract row names that. The `ai-enablement-engineer` agent uses `find-skills` during a scan to surface candidate
skills for detected gaps, and `anthropic-skills:skill-creator` to scaffold a new skill when a gap warrants one (AC-6).
Both degrade gracefully if unavailable or offline (the scan still emits structural drift and notes
the skip).

| Skill | Upstream | Pinned ref | License | Local deviations |
| --- | --- | --- | --- | --- |
| `find-skills` | [`vercel-labs/skills`](https://www.skills.sh/vercel-labs/skills/find-skills) (Vercel Labs) | `4ce6d48ac44c8b637db87b2102fea3baca719df1` | MIT (no upstream `LICENSE` file at this commit — MIT text transcribed from `package.json`/README with a provenance footer, not copied verbatim) | Usage constraint (not a file edit — vendored `SKILL.md` is unmodified): `ai-enablement-engineer` uses this skill for surfacing/suggesting skill-gap candidates only; its `npx skills add`/`update` install commands are never run during a scan or apply — see `analyze-protocol.md#skill-usage-guardrails`. |

**Refresh strategy:** manual only. The optional vendored-skill-staleness drift check (advisory) may
surface a newer reachable upstream ref, but never auto-updates; a refresh is a normal reviewed PR that
re-vets and re-pins the vendored copy, updating this table.
