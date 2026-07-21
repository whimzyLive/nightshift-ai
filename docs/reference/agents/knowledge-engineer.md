---
title: 'knowledge-engineer'
description: 'Knowledge curator: SDLC agent that owns ADR curation: turns founder-known patterns and the accumulated learnings corpus into curated, indexed Architecture Decision Records under docs/adr/. Runs the shared ADR pipeline behind /sdlc:docs seed adr + /sdlc:docs distill and regenerates docs/adr/index.md deterministically from ADR frontmatter. Also runs the /sdlc:docs sync pipeline: diff-drives deterministic regeneration of frontmatter-driven reference docs plus llms.txt, and drafts gated how-to refreshes. And runs the /sdlc:docs release pipeline: aggregates the stories merged since the last tag into the manifest-enabled subset of changelog, ADR-linked release notes, and a migration-guide stub, then writes the founder-confirmed drafts and regenerates the doc index plus llms.txt. Also runs the /sdlc:docs seed pipeline: scaffolds a manifest-activated narrative doc type for inline founder authoring, then writes the confirmed page and regenerates the doc index plus llms.txt. Also runs the /sdlc:docs audit pipeline: scans every activated row for drift, corrects auto rows into a PR, and flags narrative drift. Triggered manually via /sdlc:docs sync, release, seed, audit, seed adr, or distill.'
---

# knowledge-engineer

Knowledge curator: SDLC agent that owns ADR curation: turns founder-known patterns and the accumulated learnings corpus into curated, indexed Architecture Decision Records under docs/adr/. Runs the shared ADR pipeline behind /sdlc:docs seed adr + /sdlc:docs distill and regenerates docs/adr/index.md deterministically from ADR frontmatter. Also runs the /sdlc:docs sync pipeline: diff-drives deterministic regeneration of frontmatter-driven reference docs plus llms.txt, and drafts gated how-to refreshes. And runs the /sdlc:docs release pipeline: aggregates the stories merged since the last tag into the manifest-enabled subset of changelog, ADR-linked release notes, and a migration-guide stub, then writes the founder-confirmed drafts and regenerates the doc index plus llms.txt. Also runs the /sdlc:docs seed pipeline: scaffolds a manifest-activated narrative doc type for inline founder authoring, then writes the confirmed page and regenerates the doc index plus llms.txt. Also runs the /sdlc:docs audit pipeline: scans every activated row for drift, corrects auto rows into a PR, and flags narrative drift. Triggered manually via /sdlc:docs sync, release, seed, audit, seed adr, or distill.

## Tools

`Read`, `Write`, `Edit`, `Bash`, `Skill`, `mcp__plugin_claude-mem_mcp-search__observation_search`, `mcp__plugin_claude-mem_mcp-search__get_observations`

## Source

**Source:** `plugins/sdlc/agents/knowledge-engineer.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
