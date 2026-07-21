---
title: '/sdlc:docs'
description: 'Generate and maintain this repo''s public docs surface via the doc-type registry and per-repo docs manifest. Ships five live modes: `sync` diff-drives deterministic reference-doc + `llms.txt` regen and drafts gated how-to refreshes; `release <version>` aggregates merged stories since the last tag into changelog/release-notes/migration-guide; `seed <type> [topic]` scaffolds one new narrative page for founder authoring at the confirm gate (`seed adr "<pattern>"` routes to the ADR pipeline instead); `audit [--dry-run]` scans activated rows for drift, auto-corrects via PR, flags narrative drift; `distill ["<focus>"]` mines the learnings corpus for promotable ADR candidates via refs/adr-pipeline.md. All modes regenerate the doc index + `llms.txt` where applicable, run behind the knowledge-engineer agent, with the founder-confirmation gate at this command layer.'
---

# /sdlc:docs

Generate and maintain this repo's public docs surface via the doc-type registry and per-repo docs manifest. Ships five live modes: `sync` diff-drives deterministic reference-doc + `llms.txt` regen and drafts gated how-to refreshes; `release <version>` aggregates merged stories since the last tag into changelog/release-notes/migration-guide; `seed <type> [topic]` scaffolds one new narrative page for founder authoring at the confirm gate (`seed adr "<pattern>"` routes to the ADR pipeline instead); `audit [--dry-run]` scans activated rows for drift, auto-corrects via PR, flags narrative drift; `distill ["<focus>"]` mines the learnings corpus for promotable ADR candidates via refs/adr-pipeline.md. All modes regenerate the doc index + `llms.txt` where applicable, run behind the knowledge-engineer agent, with the founder-confirmation gate at this command layer.

## Source

**Source:** `plugins/sdlc/commands/docs.md`

The source file is authoritative for full behavior (modes, gates, control flow) — this page is a frontmatter-derived summary only; it never copies or summarizes the source body.
