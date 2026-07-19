---
status: accepted
agents: [ai-enablement-engineer, qa-engineer]
source-stories: [NA-25, NA-27, NA-43, NA-51, NA-52, NA-54, NA-57, NA-58, NA-60, NA-61, NA-62]
---

# 0002. In-tree two-pass Prettier idempotency check for plugin markdown

## Status

Accepted

## Decision

We will treat a pre-commit `prettier --check`/`--write` dry run as **never sufficient
proof** of what a real `git commit` will actually produce for any file under
`plugins/sdlc/**/*.md`. Before committing any such edit, we will: (1) copy the edited
content to a scratch `.md`-suffixed file _inside the repo tree_ (never `/tmp`, never a
`.gitignore`d directory — both silently make Prettier report `ignored: true` and
no-op); (2) confirm via `prettier --file-info` that the scratch copy is both
`ignored: false` **and** has a non-null `inferredParser`; (3) run `prettier --write`
on it twice and require the second pass to be byte-identical to the first
(idempotence); (4) after the real commit lands, re-read the file from the committed
tree (`git show HEAD:<file>`) and confirm it still matches, since the repo's real
`lint-staged` pre-commit hook runs its own `prettier --write` that can differ from any
prior dry run.

## Context

This repo's `.prettierrc` uses `proseWrap: preserve`, and the pre-commit `lint-staged`
hook runs `prettier --write --ignore-unknown` on every staged file at commit time — a
real rewrite pass distinct from, and not guaranteed to match, whatever a developer ran
by hand beforehand. Across more than a dozen stories, Prettier's remark-based Markdown
parser has been shown to silently corrupt content that a pre-commit `--check` reported
as clean: splitting fenced code blocks nested under list items into mismatched
fences, reflowing a paragraph's indentation once an adjacent fence's list-continuation
boundary changes, escaping bare `*` glyphs in prose, collapsing pipe characters inside
unescaped code spans sitting in table cells, misreading a wrapped "1)" as a new ordered
list item, and more — each a genuinely distinct corruption signature discovered
independently, sometimes by review rather than by any verification step the author had
already run. Scratch-copy verification done outside the repo tree, or against a
non-`.md`-suffixed filename, silently no-ops and produces a false "stable" result with
zero signal value.

## Alternatives Considered

### Trust a single `prettier --check` pass before committing

- Pros: cheap, fast, matches most contributors' default workflow.
- Cons: repeatedly proven insufficient in this exact repo — multiple stories shipped
  corrupted markdown that a pre-commit `--check` had reported clean, because the actual
  commit-time `lint-staged` write pass produced different output than the developer's
  own dry run.

### Disable the pre-commit Prettier hook for `plugins/sdlc/**`

- Pros: removes the source of surprise rewrites entirely.
- Cons: would let genuinely unformatted markdown land uncaught; the hook itself isn't
  the problem, the failure to verify its actual output is.

## Consequences

- Adds real verification overhead (scratch-copy, two-pass write, post-commit re-read) to
  every markdown-touching plugin story — but this cost is already what the corpus shows
  actually catches real, ship-blocking corruption; skipping it has repeatedly shipped
  defects to review instead of catching them pre-commit.
- A single same-file two-pass check is not sufficient on its own if the SAME file has
  other corruption elsewhere in the same reflow unit (e.g. the same paragraph) — the
  whole paragraph/list-item span must be checked, not just the touched lines.
- Revisit this decision if the repo's Prettier/remark version changes in a way that
  resolves these parser ambiguities upstream, or if `plugins/sdlc/**` moves off Prettier
  formatting entirely.
