---
title: '/sdlc:loop'
description: 'Per-pass logic for the code review-and-fix cycle. Each invocation probes PR status, applies the decision table (wait / fix / stop), and returns; the native /loop command handles re-invocation and pacing. The reviewer is configurable per-repo (Review agent: github-copilot | claude-inline | claude-superpowers): Copilot reviews asynchronously as a PR reviewer, claude-inline runs /code-review in-session, claude-superpowers runs the superpowers requesting-code-review skill in-session. Exits cleanly only when the current HEAD has been reviewed, all inline comments are resolved, and all required status checks pass. Halts and surfaces the failure if /review-fix errors or blocks. Does NOT merge the PR.'
---

# /sdlc:loop

Per-pass logic for the code review-and-fix cycle. Each invocation probes PR status, applies the decision table (wait / fix / stop), and returns; the native /loop command handles re-invocation and pacing. The reviewer is configurable per-repo (Review agent: github-copilot | claude-inline | claude-superpowers): Copilot reviews asynchronously as a PR reviewer, claude-inline runs /code-review in-session, claude-superpowers runs the superpowers requesting-code-review skill in-session. Exits cleanly only when the current HEAD has been reviewed, all inline comments are resolved, and all required status checks pass. Halts and surfaces the failure if /review-fix errors or blocks. Does NOT merge the PR.

## Source

**Source:** `plugins/sdlc/commands/loop.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
