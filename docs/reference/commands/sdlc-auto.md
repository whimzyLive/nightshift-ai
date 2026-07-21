---
title: '/sdlc:auto'
description: 'Full SDLC automation for a Jira story. Quality-assesses and triages if needed, then delegates the complexity decision to the shared triage protocol (refs/triage.md, applied inline) and routes a `full` story through the two-phase spec → review-gate → plan+impl-single-PR flow, or a `lightweight` story (<= threshold pts, inclusive) straight to implementation. Posts Jira comments at each gate with clickable PR links. Pass --async-review for non-blocking service-driven execution where JSON-RPC events replace the human confirmation gate.'
---

# /sdlc:auto

Full SDLC automation for a Jira story. Quality-assesses and triages if needed, then delegates the complexity decision to the shared triage protocol (refs/triage.md, applied inline) and routes a `full` story through the two-phase spec → review-gate → plan+impl-single-PR flow, or a `lightweight` story (<= threshold pts, inclusive) straight to implementation. Posts Jira comments at each gate with clickable PR links. Pass --async-review for non-blocking service-driven execution where JSON-RPC events replace the human confirmation gate.

## Source

**Source:** `plugins/sdlc/commands/auto.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
