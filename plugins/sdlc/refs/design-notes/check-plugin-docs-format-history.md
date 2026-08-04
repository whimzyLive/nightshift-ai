# Design note — why check-plugin-docs-format.sh exists, and why plain prettier

**Never auto-loaded** — extracted from `plugins/sdlc/scripts/check-plugin-docs-format.sh`'s header
comment (NA-86 A10). This is history and tool-choice rationale; it explains why the gate was
written, not what it currently does or how to fix a failure — those live in the script's own
`USAGE` and `SCOPE NARROWED BY NA-86 / ADR 0016` header sections, which stay inline.

## Why this gate exists (NA-62)

Prettier 3.6.2 is non-idempotent on certain fenced command blocks: a well-formed committed
`plugins/**/*.md` file can satisfy `format(X) != X` (state 1 — well-formed but UNSTABLE), so the
next unguarded `prettier --write` (a pre-commit hook, editor-on-save, or any PR touching it)
shatters runnable command blocks into broken four-backtick fences (the NA-56 corruption). CI's
line-34 format check is affected-only (`--base`-scoped), so a latent state-1 file not in the
current diff ships green. This gate runs the SAME native `prettier --check` predicate over ALL
`plugins/**/*.md` on every PR, closing that scope hole.

(NA-86 / ADR 0016 subsequently moved `plugins/sdlc/**/*.md` out of Prettier's reach entirely via
`.prettierignore`, eliminating the NA-56 corruption class for that tree outright — see ADR 0016.
This gate, and the history above, remain relevant for `plugins/gtm/**`, the one plugin tree ADR
0016 did not touch.)

## Why plain `prettier`, not `nx format:check` (deliberate CLAUDE.md nx-first deviation)

`nx format:check` is project-graph-based; `plugins/**/*.md` belong to no nx project, so no nx form
checks every plugin markdown file BY PATH. `prettier --check` over the path glob is the correct
(and only) tool for an all-files check of these non-project files. See NA-62 spec Decision 3.
