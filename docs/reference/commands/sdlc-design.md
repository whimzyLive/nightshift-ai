---
title: '/sdlc:design'
description: 'Attach a design to a Jira ticket. Ingests HTML exports (standalone bundles are unpacked into one readable page each, with a headless render per page), screenshots, handoff folders, and any non-design reference files into docs/design/<slug>/, writes the design index, raises a docs PR, and links it on the ticket and its parent Epic. Run when the design is final — after /prd settles the requirements (when the feature has one), before /stories or /refine-issue — so refinement can put the right part of the design on each story.'
---

# /sdlc:design

Attach a design to a Jira ticket. Ingests HTML exports (standalone bundles are unpacked into one readable page each, with a headless render per page), screenshots, handoff folders, and any non-design reference files into docs/design/<slug>/, writes the design index, raises a docs PR, and links it on the ticket and its parent Epic. Run when the design is final — after /prd settles the requirements (when the feature has one), before /stories or /refine-issue — so refinement can put the right part of the design on each story.

## Source

**Source:** `plugins/sdlc/commands/design.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
