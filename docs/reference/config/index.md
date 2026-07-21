---
title: 'Configuration reference'
description: 'The sdlc and gtm plugin config-contract templates a consumer repo fills in: project context, agent overrides, the docs manifest, Jira story/bug templates, and the gtm marketing-context/README templates.'
---

# Configuration reference

The sdlc and gtm plugin config-contract templates a consumer repo fills in: project context, agent overrides, the docs manifest, Jira story/bug templates, and the gtm marketing-context/README templates.

---

## Config templates

### Agent override template

This file is the canonical template for `.claude/project/agents/<agent>.md`. `/init` Step 4c generates one file per active domain agent by filling the token slots below. No placeholder tokens (`<...>`) may remain in the generated files: every slot must be replaced with an actual value.

**Source:** `plugins/sdlc/refs/agent-override-template.md`

### Docs manifest template

Template for the consumer-repo artifact `.claude/project/docs-manifest.md`, written by `/sdlc:init` Step 4g on the docs opt-in. It is a **separate sibling file** to `refs/doc-types.md` (decided, founder review, PR #112): never a section inside `doc-types.md`, and never inside `refs/project-context-template.md`.

**Source:** `plugins/sdlc/refs/docs-manifest-template.md`

### Jira bug template

Canonical **bug** format: parallel to `${CLAUDE_PLUGIN_ROOT}/refs/jira-story-template.md`, but for defect tickets (`issuetype == Bug`). `scrum-master` produces/normalises Bugs using this exact 7-section structure in **Mode 2 (Triage/refine, via `/refine-issue`)** and gates against it in **Mode 3 (Auto-Assess, via `/auto` Step 1)**. A Bug has **no Mike-Cohn user-story structure** (no "As a / I want / So that", no `taskList` acceptance criteria); do not force the story template onto it.

**Source:** `plugins/sdlc/refs/jira-bug-template.md`

### Jira story template

Canonical story format. Both `/stories` (Epic decomposition) and `/refine-issue` (triage/refine) produce stories using this exact template. Never vary the structure: consistency lets the team scan stories predictably.

**Source:** `plugins/sdlc/refs/jira-story-template.md`

### Project context template

This file is the canonical template for `.claude/project/project-context.md`. `/init` Step 4b fills the token slots below with real values collected and detected during setup. No placeholder tokens (`<...>`) may remain in the generated file: every slot must be replaced with an actual value.

**Source:** `plugins/sdlc/refs/project-context-template.md`

### gtm docs README template

Used by `/gtm:init` Step 5 to write `docs/gtm/README.md`: the entry point explaining the marketing working directory this plugin scaffolds. Three required sections; no placeholder tokens may remain in the written file.

**Source:** `plugins/gtm/refs/docs-gtm-readme-template.md`

### Marketing context template

Canonical template for `.claude/project/marketing-context.md`: the gtm counterpart to sdlc's `project-context.md`. `/gtm:init` Step 5 fills this template from the collected/detected values; no placeholder tokens (`<...>`) may remain in the generated file. Distinct from `.agents/product-marketing.md`, which the marketingskills `product-marketing` skill owns; this file holds gtm's own operational config and points at that file as the canonical product-marketing detail.

**Source:** `plugins/gtm/refs/marketing-context-template.md`
