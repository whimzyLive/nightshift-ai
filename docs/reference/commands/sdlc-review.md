---
title: '/sdlc:review'
description: 'Run ONLY the QA code-quality loop (review → fix → re-review until clean) without re-running the implementation lifecycle. With a story key → reviews its fix/ or feat/<STORY-KEY> branch (whichever exists) against the plan + ACs. With no key → Diff mode: reviews the current working changes vs develop. Runs the QA Engineer playbook inline. Not for implementing.'
---

# /sdlc:review

Run ONLY the QA code-quality loop (review → fix → re-review until clean) without re-running the implementation lifecycle. With a story key → reviews its fix/ or feat/<STORY-KEY> branch (whichever exists) against the plan + ACs. With no key → Diff mode: reviews the current working changes vs develop. Runs the QA Engineer playbook inline. Not for implementing.

## Source

**Source:** `plugins/sdlc/commands/review.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
