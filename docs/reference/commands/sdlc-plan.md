---
title: '/sdlc:plan'
description: "Produce an implementation plan for a full-path Jira story from its approved spec, committed to the story's feat/ branch (no PR of its own) so it ships in the implementation PR. Off by default — an approved spec's Implementation tasks are the task list. /auto and /impl run it only when project-context sets `Plan step` to `on`; run it by hand any time."
---

# /sdlc:plan

Produce an implementation plan for a full-path Jira story from its approved spec, committed to the story's feat/ branch (no PR of its own) so it ships in the implementation PR. Off by default — an approved spec's Implementation tasks are the task list. /auto and /impl run it only when project-context sets `Plan step` to `on`; run it by hand any time.

## Source

**Source:** `plugins/sdlc/commands/plan.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
