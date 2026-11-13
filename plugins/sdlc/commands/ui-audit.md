---
description: Audit an Epic's UI for the same pattern built twice, display logic in pages, restyled shared components and pages off a template. Scans the repo's UI paths on a Sonnet agent, returns a findings table and proposed library stories, and creates none without confirmation. Run at epic close.
---

`/sdlc:ui-audit [<EPIC>]` — a fixed prompt on a `general-purpose` agent (model `sonnet`), run when an Epic closes or whenever a UI cleanup is due. Principles it checks: `${CLAUDE_PLUGIN_ROOT}/refs/design-workflow.md`.

## Step 1 — Resolve scope

```text
read .claude/project/project-context.md: workspace->agent table, `UI library`, `Pattern vocabulary`, `Bundle inventory`, `Library label` (default `Library`)
UI_PATHS := the paths of every workspace->agent row owned by web-engineer or mobile-engineer, plus `UI library`
UI_PATHS empty -> STOP "no UI paths in the workspace->agent table"
EPIC := the argument when it matches <PROJECT-KEY>-\d+ | none
EPIC given -> narrow to the files the Epic's merged feat/ PRs touched: gh pr list --search "head:feat/<child>" per child (parent = <EPIC>), union of `gh pr diff --name-only`, filtered to UI_PATHS
no EPIC -> the whole of UI_PATHS
```

## Step 2 — Scan (agent)

Dispatch a `general-purpose` agent with `model: "sonnet"` and this prompt, filling the angle-bracket values:

```text
Read-only audit; change nothing. Scope: <UI_PATHS or the Epic's file list>. Vocabulary: <Pattern vocabulary path>. Bundle inventory: <Bundle inventory path>.
Find, with file:line evidence for every finding:
1. DUPLICATE   the same UI pattern built more than once as page code (two or more sites with the same structure and different names)
2. LOGIC       display logic in a page or screen file: formats, initials, tints, status-to-colour mapping, count/plural text — logic a shared component should own
3. RESTYLE     a shared library component restyled at its call site (className override, a wrapper that re-skins it) instead of changed in the library
4. OFF-TEMPLATE  a page not built on one of the vocabulary's page templates
Skip: test files, stories, generated files (*.gen.*), the library's own internals.
Report a table `Class | Pattern | Sites (file:line, comma-separated) | Suggested component` and one line per class with the count. Under 60 lines; no prose.
```

## Step 3 — Propose library stories

```text
every DUPLICATE and LOGIC row, and every RESTYLE row seen at 2+ sites -> one proposed library story: summary, Component, the Sites to replace, label `Library label`; same ACs as refs/component-plan.md Library stories (cleanup AC lists the sites)
a RESTYLE seen once, an OFF-TEMPLATE row -> listed as a finding, no story
nothing found -> say so; no stories
```

## Step 4 — Confirm and create

```text
SDLC_SESSION_KEY unset -> show the findings table and the proposals; AskUserQuestion `Create the stories` | `Edit first` | `Do nothing`; create via acli only after `Create the stories`, under <EPIC> when given
SDLC_SESSION_KEY set (headless) -> create nothing; post the findings table and the proposals as a Jira comment on <EPIC> (none given -> print them), prefixed `UI audit:`
```

Return: the findings counts per class, the table, the proposed or created story keys.

## Final action — release the session (required)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

Silent no-op outside the automation worker (`SDLC_SESSION_KEY` unset).

Epic key (optional):
$ARGUMENTS
