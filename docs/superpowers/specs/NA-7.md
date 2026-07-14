# /gtm:docs — Documentation SEO Audit & Improvement PRs — Technical Spec

**Story:** NA-7 — Audit docs and open SEO improvement PRs
**Epic:** NA-2 — GTM marketing plugin for nightshift marketplace
**Feature:** docs/features/2026-07-07-gtm-marketing-plugin.md
**Date:** 2026-07-14

> I'm using the writing-specs skill to produce this spec.

## Overview

Adds `/gtm:docs` to the gtm plugin: a command that audits this repo's existing documentation against
marketingskills `ai-seo` + `content-strategy` guidance and opens one improvement PR per finding
group, each PR citing the audit finding it fixes. A clean audit (no findings) opens nothing.

## Scope & Applicability

This is a **plugin-authoring story** owned by the `ai-enablement-engineer` agent (`plugins/` per the
project-context workspace→agent table). It ships Markdown command + agent definitions and refs — no
runtime service. Therefore the following writing-specs sections are **not applicable** and are
omitted: **Data Model** (no database), **Web UI** (no app route/component change — `apps/marketing/`
is untouched), **Mobile UI** (no mobile app), **Offline Sync** (no sync layer). The classic "API
Surface" is re-framed below as the **Command & Agent Surface**, and "Backend Implementation" as the
**Implementation Guide** for the `plugins/gtm` workspace.

## Artifact / File Surface

### New files

| File                                    | Type               | Owner                  | Purpose                                                                                         |
| --------------------------------------- | ------------------ | ---------------------- | ----------------------------------------------------------------------------------------------- |
| `plugins/gtm/commands/docs.md`          | Command definition | ai-enablement-engineer | Thin orchestrator — precondition, dispatch, report                                              |
| `plugins/gtm/agents/docs-auditor.md`    | Agent definition   | ai-enablement-engineer | Audits docs, authors + opens the improvement PRs                                                |
| `plugins/gtm/refs/docs-audit-rubric.md` | Ref                | ai-enablement-engineer | Maps ai-seo + content-strategy criteria to a concrete pass/flag rubric + finding-group taxonomy |

### Modified files

| File                                             | Change                                                                                                                |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `plugins/gtm/.claude-plugin/plugin.json`         | Bump `version` (patch) — new command shipped. No dependency change (`marketing-skills` marketplace already declared). |
| `plugins/gtm/refs/marketing-context-template.md` | Add a `Docs audit` block (audit path glob + exclude globs) so init seeds it; see Config below.                        |
| `README.md` (plugin) `plugins/gtm/README.md`     | Document the new `/gtm:docs` command in the command list.                                                             |

No generated/mirror files (`agents/`, `.codex/`, `.opencode/`, `.gemini/`) are hand-edited — they are
machine-maintained by the nx generator per the workspace→agent table.

### Config (read from `.claude/project/marketing-context.md`)

`/gtm:docs` is generic across repos, so the audit corpus is config-driven, seeded by `/gtm:init`:

| Field                 | Type      | Default                                                                                                   | Notes                                                 |
| --------------------- | --------- | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `Docs audit paths`    | glob list | `README.md`, `docs/**/*.md`, `docs/**/*.mdx`                                                              | Human-facing documentation to audit                   |
| `Docs audit excludes` | glob list | `docs/superpowers/**`, `docs/features/**`, `docs/gtm/digests/**`, `docs/gtm/briefs/**`, `**/CHANGELOG.md` | SDLC/gtm internal + machine artifacts — never audited |

If the field is absent (config predates this story), the command falls back to these defaults and
notes the fallback in its report.

## Command & Agent Surface

### Command: `/gtm:docs`

Thin orchestrator mirroring `/gtm:site` — holds no audit logic; dispatches `docs-auditor`, then
reports. Receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness.

**Flags:**

| Flag                       | Optional | Behaviour                                                                                                        |
| -------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------- |
| `--dry-run`                | yes      | Run the full audit and report findings **inline**, but open **no** PRs.                                          |
| `--paths <glob[,glob...]>` | yes      | Override the configured `Docs audit paths` for this run only.                                                    |
| `--max-prs <n>`            | yes      | Cap the number of PRs opened this run (default `5`). Excess finding groups are listed in the report as deferred. |

### Agent: `docs-auditor` (dispatch-only)

Never invoked inline by a command or directly by the founder — dispatched only by `/gtm:docs`,
mirroring the `content-writer` dispatch contract.

**Agent frontmatter contract:**

| Field    | Value                                                                                                                                  |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `name`   | `docs-auditor`                                                                                                                         |
| `model`  | `opus`                                                                                                                                 |
| `tools`  | `Read, Write, Bash, Skill, Grep, Glob`                                                                                                 |
| `skills` | `ai-seo`, `content-strategy` (both loaded via the Skill tool, per the NA-25 resume workaround — not relied on via frontmatter preload) |

Resolves `${CLAUDE_PLUGIN_ROOT}` via `.claude/.gtm-plugin-root` (the standard agent plugin-root
resolver block — the command writes the marker before dispatch).

**Agent input (from the command):** the resolved audit path globs, exclude globs, `--dry-run` state,
and `--max-prs` cap.

**Agent output (returned inline to the command):**

```typescript
interface DocsAuditFinding {
  id: string; // stable slug, e.g. "readme-missing-h1-keyword"
  category: DocsFindingCategory;
  file: string; // repo-relative path the finding applies to
  severity: 'high' | 'medium' | 'low';
  summary: string; // one-line description of the issue
  recommendation: string; // the concrete change proposed
  rubricRef: string; // which ai-seo / content-strategy criterion (rubric id) it maps to
}

type DocsFindingCategory =
  | 'metadata' // title/description/frontmatter, OG, canonical
  | 'structure' // heading hierarchy, scannability, TOC
  | 'keyword-intent' // target query/intent coverage, terminology consistency
  | 'answerability' // AI-search / llms.txt / question-shaped content (ai-seo)
  | 'internal-linking' // cross-links, orphan pages
  | 'freshness'; // stale/inconsistent content vs product reality

interface DocsAuditPr {
  findingIds: string[]; // findings this PR addresses (>= 1)
  branch: string; // gtm/docs-audit/<group-slug>
  url: string; // opened PR URL (empty on --dry-run)
}

interface DocsAuditResult {
  findings: DocsAuditFinding[]; // [] when the corpus is clean
  prs: DocsAuditPr[]; // [] on a clean audit OR --dry-run
  deferredGroups: string[]; // group slugs beyond --max-prs
  corpusFilesAudited: number;
}
```

### Invocation & permissions

There is no multi-role RBAC surface here — the gtm plugin has a single human actor (the founder) plus
a dispatch-only agent. The "permission" table below is the invocation-authority matrix (the plugin
analog of an endpoint permission row) — every surface has exactly one row.

| Surface                   | Founder (human)               | `docs-auditor` agent | Any other command  |
| ------------------------- | ----------------------------- | -------------------- | ------------------ |
| `/gtm:docs` (invoke)      | ✓                             | ✗                    | ✗                  |
| `docs-auditor` (dispatch) | ✗ (never direct)              | —                    | ✓ only `/gtm:docs` |
| Open a PR / push a branch | via the command               | ✓ (executes it)      | ✗                  |
| Merge a doc PR            | ✓ (manual — see Out of Scope) | ✗                    | ✗                  |

Git/GitHub authority is delegated: the agent runs `git`/`gh` under the founder's local credentials.
It only ever **opens** PRs — never merges (AC / Out of Scope).

## Implementation Guide (`plugins/gtm` — ai-enablement-engineer)

Follow the existing gtm conventions established by `commands/site.md` and `agents/content-writer.md`.

### `commands/docs.md` — step structure (WHAT each step does)

1. **Precondition.** Verify `.claude/project/marketing-context.md` and `.agents/product-marketing.md`
   both exist and are non-empty (ai-seo/content-strategy need product + audience context). If either
   is missing → STOP with: `Run /gtm:init first — marketing context is not set up.` (Same guard shape
   as `/gtm:site`.)
2. **Plugin-root marker.** Write `.claude/.gtm-plugin-root` from the native `${CLAUDE_PLUGIN_ROOT}`
   if absent (gitignored per-machine cache) so the dispatched agent can resolve it.
3. **Resolve corpus.** Read `Docs audit paths` / `Docs audit excludes` from marketing-context (or the
   `--paths` override / documented defaults). Note any fallback in the report.
4. **Idempotency guard.** List open PRs whose head branch matches `gtm/docs-audit/*` (via `gh pr list`).
   Pass the existing set to the agent so it skips re-opening a PR for a finding group that already has
   an open PR (mirrors the gh-cli "PR already exists → do not duplicate" rule).
5. **Dispatch `docs-auditor`** with the resolved globs, `--dry-run`, `--max-prs`, and the existing-PR
   set. Wait for the `DocsAuditResult`.
6. **Report** (see Error Handling / report contract). The command opens no PRs itself — the agent does.

### `agents/docs-auditor.md` — responsibilities (WHAT, not line-by-line HOW)

1. Load `ai-seo` and `content-strategy` skills via the Skill tool.
2. Enumerate the corpus via Glob against the resolved include globs minus excludes.
3. Audit each file against `refs/docs-audit-rubric.md`, producing `DocsAuditFinding[]`.
4. Group findings into PR-sized units — **default grouping = by `file`** (all findings for one doc =
   one PR), falling back to grouping by `category` when a single finding spans many files (e.g. a
   site-wide internal-linking fix). Cap opened groups at `--max-prs`; list the rest in `deferredGroups`.
5. For each group (skipped entirely on `--dry-run` and for groups already covered by an open PR):
   branch `gtm/docs-audit/<group-slug>` off the base branch, apply the recommended doc edits with the
   Write tool, commit (`docs(<scope>): <finding summary>`), push, and open a PR via `gh pr create`
   whose body lists every `findingId` + `rubricRef` it addresses (AC-3).
6. Return the `DocsAuditResult` inline to the command.

Base branch for audit PRs: `develop` (project-context Base branch). PR title convention:
`docs(<scope>): <group summary>`; branch convention: `gtm/docs-audit/<group-slug>` (namespaced so the
step-4 idempotency guard can match it).

### `refs/docs-audit-rubric.md`

Enumerates each concrete audit check as a rubric id mapped to its source criterion (ai-seo or
content-strategy) and the `DocsFindingCategory` it feeds. This ref is the contract the agent's
`rubricRef` values point at, so findings are traceable to guidance (AC-1).

## Error Handling

| Scenario                                                               | Behaviour                                                                                               | Outcome                                                 |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `marketing-context.md` or `.agents/product-marketing.md` missing/empty | STOP at precondition with the `/gtm:init` guidance                                                      | No dispatch, no PR                                      |
| `.claude/.gtm-plugin-root` missing                                     | Not an error — command writes it before dispatch (gitignored cache)                                     | Proceeds                                                |
| Corpus resolves to zero files (globs match nothing / all excluded)     | Agent returns empty `findings`; command reports "no documentation matched the audit paths"              | Clean no-op, no PR                                      |
| Audit finds **no** issues (corpus clean)                               | Agent returns `findings: []`, `prs: []`                                                                 | Clean no-op — **no PR opened** (AC-4)                   |
| `--dry-run` passed                                                     | Agent audits + returns findings, opens no PR                                                            | Report-only                                             |
| Finding group already has an open `gtm/docs-audit/*` PR (step-4 guard) | Agent skips that group                                                                                  | No duplicate PR                                         |
| Finding groups exceed `--max-prs`                                      | Open up to the cap; list the remainder in `deferredGroups`                                              | Partial, reported                                       |
| `gh`/`git` not authenticated or push rejected                          | Agent stops the PR loop, returns findings + the git error; command surfaces it                          | Findings reported, PRs failed — surfaced, not swallowed |
| A skill (`ai-seo` / `content-strategy`) unavailable at dispatch        | Agent degrades: audits with the remaining skill + the rubric ref, flags the missing skill in the report | Degraded audit, non-fatal                               |

**Report contract (command → founder):** files audited count; findings grouped by category with
severity; the list of opened PR URLs each mapped to its finding ids; deferred groups; any degraded
state (skill unavailable, config fallback, git failure); and — on a clean/`--dry-run`/zero-corpus run
— an explicit "no PRs opened" line with the reason.

## Out of Scope

- **Landing-page copy** — owned by `/gtm:site` / `content-writer` (separate story).
- **Automatic merging of doc PRs** — the command only opens PRs; a human reviews and merges (AC).
- **Authoring net-new documentation pages** — this audits and improves _existing_ docs; it does not
  create missing docs from scratch.
- **A Mintlify/docs-site config or build** — no `docs.json`/`mint.json` exists yet; auditing operates
  on the Markdown/MDX corpus directly and does not introduce a docs-site toolchain.
- **Channel drafts / Postiz publishing / KPI** — other gtm stories (NA-8+).
- **Scheduling / running `/gtm:docs` on a loop** — invoked manually; automation is a later concern.

## Open Questions

- [ ] **Default grouping granularity — per-file vs per-category PRs.** Suggested default: **per-file**
      (one PR per doc), falling back to per-category only when a finding legitimately spans many files.
      Keeps each PR small and reviewable while satisfying "one or more PRs" (AC-2).
- [ ] **Default `--max-prs` cap.** Suggested default: **5** — bounds PR sprawl on a first audit of a
      large corpus; overflow is reported as deferred, not dropped.
- [ ] **Should `/gtm:docs` require `/gtm:init` context (the precondition STOP)?** Suggested default:
      **yes** — ai-seo + content-strategy both consume product/audience context, and the story lists
      `/gtm:init` as a dependency. Mirrors the `/gtm:site` precondition.
- [ ] **Audit-corpus default excludes.** Suggested default: exclude `docs/superpowers/**`,
      `docs/features/**`, `docs/gtm/{digests,briefs}/**`, and `**/CHANGELOG.md` (SDLC/gtm internal +
      machine-generated artifacts); audit `README.md` + human-facing `docs/**` Markdown/MDX.
