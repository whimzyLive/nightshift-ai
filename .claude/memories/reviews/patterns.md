## 2026-07-07 — Story NA-3

**Issues found:** 1 Critical (init.md Step 5 verified PMM doc AFTER finalize mv — atomic guarantee broken, false "discarded" claim), 3 Important (portability-lint hardcoded to plugins/sdlc so new plugin unscanned; repo .gitignore missing .claude/.gtm-plugin-root while hook writes it pre-init; finalize mv order made marketing-context.md land first, so half-finalize looked like existing foundation to the re-init guard), 4 Minor (plan verify-check assumed string-array deps; sed dot-mangling; grep-based package.json reads; undocumented drift-check omission).
**Root causes:** verify/finalize ordering not treated as part of the atomic contract; single-plugin assumptions baked into shared tooling; sentinel-file semantics (guard keys on marketing-context.md) not linked to write ordering.
**Preventions:** any atomic-write step must verify ALL preconditions before the first mv; the file a re-init/existence guard keys on must be written LAST; shared repo tooling (lint) must enumerate plugins/\*/, never hardcode one; when a hook writes a file outside init, the repo shipping the hook needs the gitignore entry itself.
**Domains affected:** platform-engineer

## 2026-07-09 — Story NA-4

**Issues found:** 2 Important — (1) writer-facing meta-instructions + literal ${CLAUDE_PLUGIN_ROOT} embedded inside the rendered template fence in marketing-context-template.md (would leak into every generated marketing-context.md); (2) init.md Step 6 closing summary still claimed NA-4 config "doesn't exist yet" after this run wrote it.
**Root causes:** fenced template block treated as documentation surface rather than verbatim render surface; unblocks list not updated when the story being implemented graduated from "future" to "done".
**Preventions:** anything inside a template fence must be pure renderable output — protocol/meta prose belongs in Fill rules or outside the fence; when a command edits its own summary text, re-read neighbouring paragraphs for stale claims about the story being implemented.
**Domains affected:** ai-enablement-engineer

## 2026-07-10 — Story NA-16

**Issues found:** 1 Critical — gsap.matchMedia registered with ONLY the '(prefers-reduced-motion: reduce)' condition, so the animation callback never fired for no-preference users (ACs 2/3/4 silently unmet; page rendered correct but static). 3 Important — tests mocked mm.add and invoked the handler with fabricated conditions (green-lit the broken registration); homepage went force-dynamic with an unguarded Payload findGlobal (DB outage = homepage 500, revalidate hook dead under force-dynamic); new `hero` table had no production migration path (dev-only schema push).
**Root causes:** matchMedia mental model inverted — assumed callback always runs with conditions as booleans, but GSAP fires it only when ≥1 named condition MATCHES; mocks encoded the same wrong contract as the implementation; availability of the CMS fetch path not considered when switching the route to per-request SSR.
**Preventions:** gsap.matchMedia must always register complementary conditions (reduce + no-preference) so one always matches; when mocking a third-party contract, derive mock behaviour from real matchMedia semantics (stub window.matchMedia) so the test would fail if the registration is wrong; any request-time CMS/DB read on a public route needs a try/catch fallback to defaults; jsdom cannot see "animation never runs" bugs — add a real-browser smoke for motion work.
**Domains affected:** web-engineer

## 2026-07-10 — Story NA-22

**Issues found:** Critical: Tailwind v4 auto source detection missed symlinked workspace package (`packages/ui`) — primitives shipped unstyled; Critical (round 2): schema field added in fix (`SiteSettings.githubLabel`) without regenerating the migration — `column site_settings.github_label does not exist` at runtime. Important: stale e2e spec asserting deleted stub; admin fonts referenced in custom.scss but never loaded; `@import "tailwindcss"` without declared dep; AC2 gaps (hardcoded CTA labels, dead `hero.installCtaLabel` CMS field).
**Root causes:** Tailwind v4 doesn't follow pnpm-symlinked workspace sources — needs explicit `@source`; unit tests/lint can't catch missing utility classes (only built-CSS grep can); schema changes and migrations are separate generated artifacts — changing one without regenerating the other passes typecheck.
**Preventions:** After adding any cross-package Tailwind consumer, grep compiled `.next/static/chunks/*.css` for a package-only class; every Payload schema change on an unreleased branch regenerates the baseline migration (ts+json+index); e2e specs are in-scope when a page they assert changes; every CMS field added must be rendered somewhere or not added.
**Domains affected:** web-engineer
