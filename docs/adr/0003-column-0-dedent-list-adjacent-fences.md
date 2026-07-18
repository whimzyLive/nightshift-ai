---
status: accepted
agents: [ai-enablement-engineer, qa-engineer]
source-stories: [NA-25, NA-27, NA-43, NA-51, NA-52, NA-54, NA-57, NA-58, NA-60, NA-61, NA-62]
---

# 0003. Column-0 dedent for list-adjacent markdown fences

## Status

Accepted

## Decision

We will dedent to column 0 — fence, body, and any trailing continuation prose — any
fenced code block or paragraph sitting adjacent to (nested under, or immediately
following) a numbered/bulleted list item, rather than matching it to the list item's
content-indentation, since indentation-matching is the recurring root cause of
Prettier/remark markdown corruption in this repo.

## Context

This repo's `.prettierrc` uses `proseWrap: preserve`, and the pre-commit `lint-staged`
hook runs `prettier --write --ignore-unknown` on every staged file at commit time.
Across more than a dozen stories, Prettier's remark-based Markdown parser has been
shown to silently corrupt content that a pre-commit `--check` reported as clean:
splitting fenced code blocks nested under list items into mismatched fences, and
reflowing a paragraph's indentation once an adjacent fence's list-continuation boundary
changes — each a genuinely distinct corruption signature discovered independently,
sometimes by review rather than by any verification step the author had already run.

## Alternatives Considered

### Re-indent to match the surrounding list item instead of dedenting to column 0

- Pros: visually more "consistent" with neighboring nested content.
- Cons: repeatedly the literal root cause of the corruption this ADR exists to prevent —
  Prettier's parser requires every line inside a fence nested under a list item to
  satisfy that item's content-indentation exactly, and any content that quotes/embeds
  raw text verbatim (e.g. a Jira comment body) can't safely absorb re-indentation without
  changing the literal bytes it's meant to preserve.

## Consequences

- Column-0 dedent is now the default fix for any list-adjacent fence, rather than a
  case-by-case judgment call — trades a small amount of visual nesting consistency for
  parser stability.
- Content that quotes or embeds raw text verbatim (e.g. a Jira comment body reproduced
  in a plan/spec doc) stays byte-faithful, since it's never asked to absorb a
  list-item's content-indentation.
- Revisit this decision if the repo's Prettier/remark version changes in a way that
  resolves these parser ambiguities upstream, or if `plugins/sdlc/**` moves off Prettier
  formatting entirely.
