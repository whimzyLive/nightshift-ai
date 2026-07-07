# `docs/gtm/README.md` Template

Used by `/gtm:init` Step 5 to write `docs/gtm/README.md` — the entry point explaining the marketing
working directory this plugin scaffolds. Three required sections; no placeholder tokens may remain
in the written file.

## Template

```markdown
# GTM Working Directory

## Purpose

This directory holds nightshift's version-controlled marketing foundation: the artifacts the
`gtm` plugin and its downstream commands/agents produce as the founder runs channel, KPI,
engagement, pulse, and launch workflows on top of the foundation `/gtm:init` bootstraps.

## Directory map

| Path | Holds |
| ---- | ----- |
| `docs/gtm/digests/` | Committed pulse digests (a downstream story populates this) |
| `docs/gtm/briefs/` | GTM briefs emitted by the `product-marketing-manager` agent, named `<date>-<slug>.md` (a downstream story populates this) |

Downstream stories (channel ownership/voice/cadence, KPI setup, engagement listening, pulse,
launch) may add further placeholders here as they land — this file's directory map should be kept
current as new subdirectories appear.

## What init writes vs what downstream stories populate

- **`/gtm:init` writes:** this README, and the empty `digests/` and `briefs/` directories
  (via `.gitkeep`). That is the full scope of init's `docs/gtm/` footprint.
- **Downstream stories populate:** the digest and brief **content** itself, the append-only
  content log, campaign definitions, and any further scaffold this directory needs as the Epic's
  remaining stories (NA-4 through NA-8, NA-11) land.
```

## Fill rules

1. Write the template verbatim — there are no per-repo tokens to substitute (this file documents
   the plugin's own working-directory convention, not repo-specific product data).
2. Do not add content that belongs to a downstream story (e.g. do not pre-create campaign files or
   sample briefs) — only the structural README, `digests/.gitkeep`, and `briefs/.gitkeep`.
