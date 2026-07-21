---
title: '/sdlc:init'
description: "One-command onboarding for a new repo: interactively scaffolds .claude/project/project-context.md, the active agents' override files, the plugin-root marker, and the project skills manifest, after gating on the gh/acli prerequisites and walking you through acli authentication. Scans the repository stack to pre-fill defaults and suggest relevant skills. Safe to re-run against an already-initialised repo (merge/confirm flow). Ends with a post-init checklist of the Jira custom fields you must configure by hand."
---

# /sdlc:init

One-command onboarding for a new repo: interactively scaffolds .claude/project/project-context.md, the active agents' override files, the plugin-root marker, and the project skills manifest, after gating on the gh/acli prerequisites and walking you through acli authentication. Scans the repository stack to pre-fill defaults and suggest relevant skills. Safe to re-run against an already-initialised repo (merge/confirm flow). Ends with a post-init checklist of the Jira custom fields you must configure by hand.

## Source

**Source:** `plugins/sdlc/commands/init.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
