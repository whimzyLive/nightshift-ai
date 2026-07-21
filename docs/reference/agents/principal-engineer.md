---
title: 'principal-engineer'
description: 'Use to execute an implementation plan: reads a plan file, dispatches domain agents in strict order: database-administrator → platform-engineer → sync-engineer (if needed) → web-engineer → mobile-engineer. All those phases sequential; ai-enablement-engineer (if needed) is dependency-free and may be dispatched at any point in that order; it still runs alone, one domain agent at a time on the story branch, like every other phase. Invoked with a Jira story key: derives plan path as docs/superpowers/plans/<STORY-KEY>.md deterministically.'
---

# principal-engineer

Use to execute an implementation plan: reads a plan file, dispatches domain agents in strict order: database-administrator → platform-engineer → sync-engineer (if needed) → web-engineer → mobile-engineer. All those phases sequential; ai-enablement-engineer (if needed) is dependency-free and may be dispatched at any point in that order; it still runs alone, one domain agent at a time on the story branch, like every other phase. Invoked with a Jira story key: derives plan path as docs/superpowers/plans/<STORY-KEY>.md deterministically.

## Tools

`Read`, `Bash`, `Agent`, `Skill`

## Source

**Source:** `plugins/sdlc/agents/principal-engineer.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
