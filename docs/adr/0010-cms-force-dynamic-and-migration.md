---
status: accepted
agents: [web-engineer, qa-engineer]
source-stories: [NA-16, NA-31, NA-35, NA-36, NA-38]
---

# 0010. force-dynamic rendering and production-migration requirement for CMS-backed routes

## Status

Accepted

## Decision

We will mark every Next.js App Router page that performs a request-time Payload Local
API call `export const dynamic = 'force-dynamic'`, so the CMS is queried at request
time rather than attempted at static-prerender/build time. Any new Payload
global/collection introduced to back such a route MUST ship with a real, committed
production migration — a dev-only schema push is insufficient — since a fully migrated
Postgres schema must exist wherever the route actually runs.

## Context

A Next.js page that calls Payload's Local API directly attempts static prerendering by
default at `next build` time, which requires a fully migrated Postgres schema to exist
at build time — a brand-new global/collection with no migration yet fails the build
outright. This combination — force-dynamic rendering paired with a real production
migration, not just a local schema push — was independently re-derived on the first
CMS-reading story (NA-16) after a Critical defect, then reused as an established
pattern on every subsequent CMS-reading page (NA-31/35/36/38).

## Alternatives Considered

### Fake/mock the DB at build time to allow static prerendering

- Pros: keeps pages static, best possible performance for CMS-backed content.
- Cons: fights the actual constraint instead of addressing it; CMS content that must
  reflect admin edits without a redeploy needs request-time freshness anyway, which
  static prerendering can't provide regardless of the build-time workaround. It also
  does nothing to guarantee the production database is actually migrated — a build that
  passes with a mocked DB gives no signal about whether the live route will work.

## Consequences

- `force-dynamic` means these routes are queried on every request rather than cached as
  static output — an accepted performance cost for content that must reflect admin
  edits without a redeploy.
- A new Payload global/collection must ship a real, committed production migration
  alongside the schema change — a dev-only local schema push that's never promoted to
  an applied production migration will build and pass locally but fail (or silently
  drift) once the route is actually live against the production database.
- The [0009](0009-cms-read-try-catch-fallback.md) try/catch fallback must not be
  relied on to mask a missing migration: a `relation "<slug>" does not exist` error in
  production is a deploy defect (missing migration), not the transient DB failure that
  fallback is scoped to handle, and should surface as a loud, investigated failure
  rather than a quietly-tolerated default-content fallback.
- New CMS-reading pages get a known, copy-pasteable shape instead of re-deriving the
  force-dynamic/migration tradeoff from scratch each time.
- Revisit if a future ISR/on-demand-revalidation strategy makes static prerendering
  with fresh-enough content viable again for these routes.
