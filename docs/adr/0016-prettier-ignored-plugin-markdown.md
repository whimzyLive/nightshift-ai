---
status: accepted
agents: [ai-enablement-engineer]
source-stories: [NA-86]
---

# 0016. Prettier-ignored plugin markdown

## Status

Accepted. Supersedes [0002. In-tree two-pass Prettier idempotency check for plugin markdown](0002-in-tree-prettier-idempotency-check.md).

## Decision

We will add `plugins/sdlc/**/*.md` to `.prettierignore`, after a one-time whitespace-only table
unpad across every file in that tree. Prettier will never again format, reflow, or otherwise
rewrite a `plugins/sdlc/**/*.md` file.

## Context

`instruction-inventory.sh --padding` measured 595 padded table content rows and 75 padded
delimiter rows across `plugins/sdlc/**/*.md` at develop tip `ae0db4e` — column-aligned table
whitespace that Prettier's own formatting convention produces and that costs real, resident
instruction-load tokens (40,225 static / 54,161 per-story estimated) on every dispatch that loads
one of these files, for a stylistic property (column alignment) with no functional value once the
files stop being run through Prettier at all.

Separately, ADR 0002 already documents more than a dozen stories across which Prettier's
remark-based Markdown parser has silently corrupted `plugins/sdlc/**/*.md` content that a
pre-commit `--check` reported clean — the NA-56 corruption class (shattered fenced code blocks,
reflowed list-adjacent paragraphs, escaped bare `*` glyphs, collapsed unescaped pipes inside table
cells, misread wrapped ordinals, and more). ADR 0002's answer was a two-pass, in-tree,
scratch-copy verification procedure run before every commit — real, ongoing verification
overhead paid on every markdown-touching plugin story, in exchange for catching corruption that a
naive `--check` misses.

## Alternatives Considered

### Keep Prettier active and keep paying ADR 0002's two-pass verification cost

- Pros: no new precedent (already the established practice); catches genuine formatting drift.
- Cons: the corruption class ADR 0002 exists to catch is a byproduct of running Prettier's
  remark-based Markdown parser over this tree at all — the mitigation treats a self-inflicted
  problem, and does not touch the separate, ongoing per-story token cost of padded table columns.

### Unpad the tables but leave Prettier active

- Pros: removes the padded-row token cost without a `.prettierignore` change.
- Cons: the very next `prettier --write` — a pre-commit hook, an editor-on-save, or an unguarded
  PR — re-pads the tables and can re-trigger the NA-56 corruption class; the saving would not
  survive the next unguarded write.

### Ignore `plugins/sdlc/**/*.md` in Prettier entirely (chosen)

- Pros: the unpad becomes a durable, one-time saving (no future write can re-pad); the NA-56
  corruption class is eliminated outright, since Prettier's Markdown parser never runs against
  this tree again; ADR 0002's two-pass verification procedure becomes unnecessary for this tree
  and its cost goes away with it.
- Cons: this is precisely the option ADR 0002 rejected under its own "Disable the pre-commit
  Prettier hook for `plugins/sdlc/**`" alternative — "would let genuinely unformatted markdown
  land uncaught". That objection assumed formatting drift was worth catching automatically; this
  ADR's position is that the padded-row token cost this story measured, plus a corruption class
  Prettier itself introduces, now outweigh that benefit for this specific tree.

## Consequences

- Removes 595 padded table content rows (and 75 padded delimiter rows) from
  `plugins/sdlc/**/*.md`, a one-time, durable saving now that Prettier can never re-pad them.
- Eliminates the NA-56 corruption class for this tree outright — there is no longer a Prettier
  rewrite pass that can shatter a fenced code block or reflow a list-adjacent paragraph here.
- ADR 0002's two-pass scratch-copy verification procedure is no longer necessary for
  `plugins/sdlc/**/*.md` edits; ADR 0002 is superseded by this record rather than edited in place.
- **Vacuity risk:** after this change, `plugins/gtm/**` is the sole remaining plugin tree matched
  by `check-plugin-docs-format.sh`'s `plugins/**/*.md` glob that Prettier still checks. If a future
  change also adds `plugins/gtm/**` to `.prettierignore` (or otherwise removes it from the glob),
  that gate would check zero files and report a silent, vacuous pass — `check-plugin-docs-format.sh`
  cannot detect that case itself (a prettier-CLI limitation documented in its own header comment).
  `plugins/sdlc/scripts/__tests__/prettier-ignore.test.sh` assertion 3
  (`plugins/gtm/README.md` must still report `ignored: false`) is the only thing that would catch
  this regression — do not remove that assertion as apparently redundant.
- Manual formatting discipline (indentation, table shape) inside `plugins/sdlc/**/*.md` now falls
  to the authoring agent/human rather than to an automated formatter. Revisit this decision if a
  Prettier/remark version ships that resolves the underlying parser ambiguities ADR 0002
  documented, or if `plugins/sdlc/**` moves to a different, non-Prettier formatting tool.
- **Sibling rebase gate (cross-story obligation, ordering constraint 4).** The one-time unpad this
  ADR ships rewrites nearly every `plugins/sdlc/**/*.md` file's table whitespace. Any sibling branch
  open at the same time and also touching `plugins/sdlc/**/*.md` (e.g. NA-88, NA-90, NA-91) will
  hit a table-shaped merge conflict on its next rebase past this change. After this ADR's commit
  lands: **every such open sibling branch rebases onto it before its next push**, and any sibling PR
  whose rebase produces a **table conflict** re-runs
  `bash tools/sdlc-analyser/branch-inventory.sh <file> --base <merge-base>` on each conflicted file
  and pastes the result in its own PR body — a hand-resolved conflict on a semantically-unchanged
  table line is exactly how a decision-table row gets silently dropped, and this is the same AC-7
  gate that catches it elsewhere in this story. `OUTCOMES_MATCH=false` blocks that sibling PR.
  **Enforcement owner (per D12): the sibling PR's own author, checked at that PR's review** — NA-86
  cannot gate a branch it does not own; its obligation is only to state this rule and ship the tool
  (`tools/sdlc-analyser/branch-inventory.sh`, Phase 1). Mechanical CI enforcement on sibling
  branches is explicitly out of scope for NA-86.
