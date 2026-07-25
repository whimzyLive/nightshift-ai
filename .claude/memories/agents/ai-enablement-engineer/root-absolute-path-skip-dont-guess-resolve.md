---
id: root-absolute-path-skip-dont-guess-resolve
agent: [ai-enablement-engineer]
trigger: [dangling-link check, root-absolute path resolution, "/"-prefixed target ambiguous]
rule: A "resolve file-relative from the page's directory" rule needs an explicit carve-out for root-absolute (`/`-prefixed) targets.
evidence: [NA-68]
uses: 0
status: active
---

## Why

`/reference/errors.md` resolved file-relative from `docs/how-to/` naively becomes
`docs/how-to/reference/errors.md` (doesn't exist) — a false-positive dangling flag. When a
deterministic-path check faces an ambiguous input whose correct resolution depends on knowledge
outside its declared primitive, skip rather than guess.
