---
title: 'tech-lead'
description: "Use to convert an approved technical spec into a detailed implementation plan with tasks tagged by agent and ordered by dependency. Dispatched by /plan — by hand, or by /auto and /impl when project-context `Plan step` is `on` (off by default; the approved spec's Implementation tasks are the task list). Input: Jira story key (e.g. CER-123) and the feat/ worktree — fetches story, reads the spec in the worktree, writes the plan."
---

# tech-lead

Use to convert an approved technical spec into a detailed implementation plan with tasks tagged by agent and ordered by dependency. Dispatched by /plan — by hand, or by /auto and /impl when project-context `Plan step` is `on` (off by default; the approved spec's Implementation tasks are the task list). Input: Jira story key (e.g. CER-123) and the feat/ worktree — fetches story, reads the spec in the worktree, writes the plan.

## Tools

`Read`, `Write`, `Bash`, `Skill`

## Source

**Source:** `plugins/sdlc/agents/tech-lead.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
