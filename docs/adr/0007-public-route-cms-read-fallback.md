---
status: accepted
agents: [web-engineer, qa-engineer]
source-stories: [NA-16, NA-31, NA-35, NA-36, NA-38]
---

# 0007. Every public-route Payload/CMS read gets a try/catch-to-defaults fallback and export const dynamic = 'force-dynamic'

## Status

Accepted

## Decision

We will implement every Next.js App Router page/section that performs a request-time
Payload Local API call (`findGlobal`/`find`) as: (1) a small, dependency-free
data-access function that wraps the call in `try { return await payload.<call>(...); }
catch (e) { console.error(...); return <same defaults as the field's own defaultValue>;
}`, narrowed to `Pick<GeneratedType, 'fieldsActuallyConsumed'>`; and (2) the consuming
page marked `export const dynamic = 'force-dynamic'` so the CMS is queried at request
time rather than attempted at static-prerender/build time. The Payload fetch itself
stays at the page's single top-level async boundary; every section/component below it
receives already-resolved props and stays synchronous.

## Context

A Next.js page that calls Payload's Local API directly attempts static prerendering by
default at `next build` time, which requires a fully migrated Postgres schema to exist
at build time — a brand-new global/collection with no migration yet fails the build
outright. Separately, and independently, an unguarded `findGlobal`/`find` call on a
live, `force-dynamic` route means any transient DB outage becomes a full page 500 for
every visitor, and (per a Critical review finding on NA-16) can leave content-revalidation
hooks dead under `force-dynamic` when the read path has no fallback at all. This
combination — force-dynamic plus a resilient fallback — was independently re-derived on
the first CMS-reading story (NA-16) after a Critical defect, then reused verbatim as an
established pattern on every subsequent CMS-reading page (NA-31/35/36/38).

## Alternatives Considered

### Fake/mock the DB at build time to allow static prerendering

- Pros: keeps pages static, best possible performance for CMS-backed content.
- Cons: fights the actual constraint instead of addressing it; CMS content that must
  reflect admin edits without a redeploy needs request-time freshness anyway, which
  static prerendering can't provide regardless of the build-time workaround.

### Let a DB failure propagate as a hard error (no try/catch)

- Pros: simpler code, failure is immediately visible rather than silently degraded.
- Cons: this is the exact shape of the shipped Critical defect — a transient DB outage
  becomes a full page outage instead of a graceful degrade to static defaults, which is
  strictly worse for a public marketing page than showing slightly-stale default copy.

## Consequences

- Every CMS-backed public page degrades to its field-level default content on any read
  failure, rather than failing the whole page — a deliberate, accepted tradeoff of
  content freshness for availability during an outage.
- `force-dynamic` means these routes are queried on every request rather than cached as
  static output — an accepted performance cost for content that must reflect admin
  edits without a redeploy.
- New CMS-reading pages get a known, copy-pasteable shape instead of re-deriving the
  force-dynamic/fallback tradeoff from scratch each time.
- Revisit if a future ISR/on-demand-revalidation strategy makes static prerendering with
  fresh-enough content viable again for these routes.
