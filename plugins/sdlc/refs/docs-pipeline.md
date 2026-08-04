# Docs pipeline — index

This file is a **thin index only** — split into five mode-scoped slices at NA-79 (was a single
175,803-byte monolith; a docs-sync dispatch previously had to load the whole file to use ~90 lines).
Section numbers are preserved unchanged across the split, so an existing "§N" reference still
resolves to the same content, now in one of the files below. Read the slice(s) your dispatch
actually needs — never this index for content, and never the old monolith shape.

| Slice | Sections | Serves |
| --- | --- | --- |
| `docs-pipeline-core.md` | §§1–9 | Every mode — manifest gate, two-phase dispatch, deterministic regen algorithm, voice/format resolution, `source:` convention, no-op semantics, `sync`'s own branch/PR flow, `llms.txt` format. Always read first. |
| `docs-pipeline-release.md` | §§10–14 | `/sdlc:docs release` — merged-story enumeration, changelog aggregation + upsert, ADR-link resolution, branch/PR/control flow, no-op semantics. |
| `docs-pipeline-seed.md` | §§15–19 | `/sdlc:docs seed` — type/topic resolution, gate ladder + `PAGE` construction, page artifacts, branch/PR/control flow, no-op + re-run semantics. |
| `docs-pipeline-audit.md` | §§20–24 | `/sdlc:docs audit` — scan scope + two-tier drift model, deterministic correction, reference-integrity flagging, branch/PR/control flow. |
| `docs-pipeline-postqa.md` | §§25–26 | The Principal Engineer playbook's Step 6.5 post-QA inline-sync dispatch variant, and the dual diff-source selection rule standalone `sync` also uses. |

Every non-core slice is read **together with** `docs-pipeline-core.md`, never standalone. A Step
6.5 post-QA dispatch reads exactly `docs-pipeline-core.md` + `docs-pipeline-postqa.md` — nothing
else.

Referenced by both `agents/knowledge-engineer.md` and `commands/docs.md`, each pointing at the
specific slice(s) its own dispatch/route needs — see those files, not this index, for the
per-dispatch wiring.
