# sdlc — repo-agnostic SDLC plugin

Generic SDLC agent workflow for Claude Code. Drives Jira → spec → plan → impl → review
using a per-repo config file the consumer supplies at `.claude/project/project-context.md`.

`/auto` triages by complexity first: **small stories** (≤ the configurable lightweight threshold,
default 3 points) skip spec+plan entirely and go **straight to implementation** (tasks derived inline
from the ticket); the full spec → plan → review-gate flow is reserved for larger stories.

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
  executing-plans, subagent-driven-development, test-driven-development,
  verification-before-completion, requesting-code-review, receiving-code-review, writing-plans.
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

## Project-skill loading enforcement

Domain-agent dispatches enforce project-skill loading via a three-part contract: the **dispatch
prompt names** the applicable override skills (or explicitly declares that no project skills apply),
the **domain agent declares** the skills it invoked/applied on a required `Skills loaded:` return
line — including any named skill that happens to be frontmatter-preloaded — and the **orchestrator
verifies** the returned set covers the named set, but only on `Status: complete` returns (a
`Status: blocked` return, including an early-abort `Skills loaded: none`, is exempt). Verification is
mechanical: when the prompt declared no applicable skills, a present non-empty line passes —
`none`, or a line listing extra skills the agent chose to load, both pass; a missing, empty, or
(when skills were named) partial line fails. On failure the principal playbook redispatches the
phase once (a return-contract-only redispatch — zero new commits is an acceptable outcome) then
STOPs; the QA fix loop returns `blocked` immediately. See
`plugins/sdlc/refs/principal-engineer-playbook.md` (Steps 4-5) and
`plugins/sdlc/refs/qa-engineer-playbook.md` (Step 3).

## `/sdlc:analyze` — manual AI-config drift/gap scan

`plugins/sdlc/commands/analyze.md` dispatches `ai-enablement-engineer` for a **manual-only** repo-wide
scan (no scheduling/background trigger). Default mode is **read-only**: it reports drift, gaps, and
config-vs-memory semantic conflicts across the resolved write-scope (optionally narrowed via
`$ARGUMENTS`). Applying a proposed fix happens **only after explicit human confirmation** — never
auto-apply — and always produces a reviewable diff: a commit on the impl branch (with the PR opened
by `principal-engineer`) when dispatched on a story, or a self-raised PR on a `chore/ai-config-<slug>`
branch when run standalone.

## Bundled default skills (vendored)

`skill-creator` and `find-skills` ship **vendored** into `plugins/sdlc/skills/<name>/` (same layout as
every other skill under `plugins/sdlc/skills/`) rather than as marketplace dependencies, because both
originate from [skills.sh](https://www.skills.sh) — a skills registry, not a Claude plugin
marketplace. The `ai-enablement-engineer` agent uses `find-skills` during a scan to surface candidate
skills for detected gaps, and `skill-creator` to scaffold a new skill when a gap warrants one (AC-6).
Both degrade gracefully if unavailable or offline (the scan still emits structural drift and notes
the skip).

| Skill           | Upstream                                                                                          | Pinned ref                                 | License                                                                                                                                         | Local deviations                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| --------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `skill-creator` | [`anthropics/skills`](https://www.skills.sh/anthropics/skills/skill-creator) (Anthropic official) | `9d2f1ae187231d8199c64b5b762e1bdf2244733d` | Apache-2.0 (upstream `LICENSE.txt` carried verbatim)                                                                                            | Local modification: removed remote CDN loads (Google Fonts `<link>`s, `cdn.sheetjs.com` SheetJS `<script>`) — security/offline (no remote network loads at render time; fonts fall back to the system stack). Applied to all three files that emitted them: `eval-viewer/viewer.html` (also degrades XLSX preview to a "preview unavailable offline" message instead of loading remote JS), `assets/eval_review.html`, and `scripts/generate_report.py` (its HTML-report string template). |
| `find-skills`   | [`vercel-labs/skills`](https://www.skills.sh/vercel-labs/skills/find-skills) (Vercel Labs)        | `4ce6d48ac44c8b637db87b2102fea3baca719df1` | MIT (no upstream `LICENSE` file at this commit — MIT text transcribed from `package.json`/README with a provenance footer, not copied verbatim) | Usage constraint (not a file edit — vendored `SKILL.md` is unmodified): `ai-enablement-engineer` uses this skill for surfacing/suggesting skill-gap candidates only; its `npx skills add`/`update` install commands are never run during a scan or apply — see `analyze-protocol.md#skill-usage-guardrails`.                                                                                                                                                                               |

**Refresh strategy:** manual only. The optional vendored-skill-staleness drift check (advisory) may
surface a newer reachable upstream ref, but never auto-updates; a refresh is a normal reviewed PR that
re-vets and re-pins the vendored copy, updating this table.
