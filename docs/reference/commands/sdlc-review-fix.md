---
title: '/sdlc:review-fix'
description: "Ingest review comments from a GitHub PR or commit, triage them with the receiving-code-review skill (keep only the ones true in this app's context), fix the accepted ones via the right domain agents, re-review the applied commits, then post each comment's accept/reject justification back on its PR thread: resolving accepted threads and leaving rejected ones open. Runs the QA Engineer playbook inline. Does not re-implement or open a PR."
---

# /sdlc:review-fix

Ingest review comments from a GitHub PR or commit, triage them with the receiving-code-review skill (keep only the ones true in this app's context), fix the accepted ones via the right domain agents, re-review the applied commits, then post each comment's accept/reject justification back on its PR thread: resolving accepted threads and leaving rejected ones open. Runs the QA Engineer playbook inline. Does not re-implement or open a PR.

## Source

**Source:** `plugins/sdlc/commands/review-fix.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
