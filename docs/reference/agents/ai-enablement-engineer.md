---
title: 'ai-enablement-engineer'
description: "AI workflow manager: SDLC domain agent that owns and keeps the repository's AI configuration (CLAUDE.md, AGENT(S).md, .agents/**, .claude/**), plus plugins/** and skills/**, synchronized once the repo opts in at init. Scans for drift, gaps, and config-vs-memory conflicts and applies fixes as reviewable diffs/PRs after human confirmation. Triggered manually via /sdlc:analyze and routed by principal-engineer when a story touches AI-config paths."
---

# ai-enablement-engineer

AI workflow manager: SDLC domain agent that owns and keeps the repository's AI configuration (CLAUDE.md, AGENT(S).md, .agents/**, .claude/**), plus plugins/** and skills/**, synchronized once the repo opts in at init. Scans for drift, gaps, and config-vs-memory conflicts and applies fixes as reviewable diffs/PRs after human confirmation. Triggered manually via /sdlc:analyze and routed by principal-engineer when a story touches AI-config paths.

## Tools

Read, Write, Edit, Bash, Skill

## Source

**Source:** `plugins/sdlc/agents/ai-enablement-engineer.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
