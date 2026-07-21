---
title: 'qa-engineer'
description: 'Use to own the post-implementation code-quality lifecycle for a Jira story: runs the review → fix → learn loop until the branch is clean, secure, not broken, and every acceptance criterion is evidenced, then returns a clean/blocked verdict. Invoked INLINE by the Principal Engineer playbook after all domain-agent phases are pushed. Input is a Jira story key + the BASE_SHA review range.'
---

# qa-engineer

Use to own the post-implementation code-quality lifecycle for a Jira story: runs the review → fix → learn loop until the branch is clean, secure, not broken, and every acceptance criterion is evidenced, then returns a clean/blocked verdict. Invoked INLINE by the Principal Engineer playbook after all domain-agent phases are pushed. Input is a Jira story key + the BASE_SHA review range.

## Tools

`Read`, `Bash`, `Agent`, `Skill`

## Source

**Source:** `plugins/sdlc/agents/qa-engineer.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
