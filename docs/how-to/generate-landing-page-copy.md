---
title: How to generate landing-page copy with gtm
description: Run /gtm:site to produce reviewed, brand-correct landing-page copy with a full SEO layer and the durable site-brief.md handoff.
source:
  - plugins/gtm/commands/site.md
related-adrs: []
---

# How to generate landing-page copy with gtm

Produce reviewed, brand-correct landing-page copy with a full SEO layer, captured in the durable
`docs/gtm/site-brief.md` handoff artifact. The brief is the deliverable; building the site from it
is a separate step.

## Prerequisites

- `/gtm:init` has run in this repo. Confirm both context files exist and are non-empty:

  ```bash
  [ -s ".claude/project/marketing-context.md" ] && [ -s ".agents/product-marketing.md" ] \
    && echo ok || echo missing
  ```

  If this prints `missing`, run `/gtm:init` first — `/gtm:site` stops without it. See
  [what-is-the-gtm-plugin](../concepts/what-is-the-gtm-plugin.md) for how the plugin fits together,
  and [getting-started-with-gtm](../tutorials/getting-started-with-gtm.md) for the first-run walkthrough.

## Steps

1. Run the command:

   ```
   /gtm:site
   ```

   Add `--council` for a launch-critical page to enable the `marketing-council` critique pass. Add
   `--overwrite` to regenerate an existing brief non-interactively. See `plugins/gtm/commands/site.md`
   for the full flag list.

2. Let the run proceed. `/gtm:site` is a thin orchestrator — it dispatches the `content-writer`
   agent (`task=landing-page`) for the copy deck and full SEO layer, then gates the returned artifact
   through the shared copy-review gate (`PASS`/`FAIL`).

3. On `PASS`, the command applies `nightshift-design` brand tokens (from `brand/BRAND_KIT.md`) and
   writes the branded artifact to `docs/gtm/site-brief.md`. On `FAIL`, it emits the violation list
   with offending spans and stops — nothing is branded or written. Address the violations and re-run.

4. If `docs/gtm/site-brief.md` already exists, the command prompts before the copy run: **Refine**
   (merge new copy into the existing brief, re-gated), **Regenerate** (replace), or **Skip** (keep the
   existing brief, not re-gated). `--overwrite` bypasses the prompt and regenerates.

## Verify

Confirm the brief exists and carries the copy deck plus the SEO layer:

```bash
[ -f "docs/gtm/site-brief.md" ] && echo exists || echo missing
grep -n -i -E "copy deck|json-ld|meta|llms.txt|page map" docs/gtm/site-brief.md
```

The brief opens with a provenance header (e.g. `<!-- generated 2026-07-20 by /gtm:site -->`) and
carries the full SEO layer: page map/IA, copy deck, JSON-LD, meta/OG, and the llms.txt
recommendation.

## Next step

`docs/gtm/site-brief.md` is the terminal output. `/gtm:site` never builds the site or dispatches
build agents. To build the landing page from the brief, use the sdlc plugin's flow separately, once
the repo has the frameworks and skills the build needs.
