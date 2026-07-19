---
status: accepted
agents: [web-engineer, qa-engineer]
source-stories: [NA-16, NA-31, NA-35, NA-36, NA-38]
---

# 0009. Try/catch-to-defaults fallback for public-route CMS reads

## Status

Accepted

## Decision

We will implement every Next.js App Router page/section that performs a request-time
Payload Local API call (`findGlobal`/`find`) as a small, dependency-free data-access
function that wraps the call in `try { return await payload.<call>(...); } catch (e) {
console.error(...); return <same defaults as the field's own defaultValue>; }`,
narrowed to `Pick<GeneratedType, 'fieldsActuallyConsumed'>`. The Payload fetch itself
stays at the page's single top-level async boundary; every section/component below it
receives already-resolved props and stays synchronous.

## Context

An unguarded `findGlobal`/`find` call on a live, `force-dynamic` route means any
transient DB outage becomes a full page 500 for every visitor, and (per a Critical
review finding on NA-16) can leave content-revalidation hooks dead under
`force-dynamic` when the read path has no fallback at all. This fallback shape was
independently re-derived on the first CMS-reading story (NA-16) after a Critical
defect, then reused verbatim as an established pattern on every subsequent
CMS-reading page (NA-31/35/36/38).

## Alternatives Considered

### Let a DB failure propagate as a hard error (no try/catch)

- Pros: simpler code, failure is immediately visible rather than silently degraded.
- Cons: this is the exact shape of the shipped Critical defect — a transient DB outage
  becomes a full page outage instead of a graceful degrade to static defaults, which is
  strictly worse for a public marketing page than showing slightly-stale default copy.

## Consequences

- Every CMS-backed public page degrades to its field-level default content on any read
  failure, rather than failing the whole page — a deliberate, accepted tradeoff of
  content freshness for availability during an outage.
- New CMS-reading pages get a known, copy-pasteable shape instead of re-deriving the
  fallback tradeoff from scratch each time.
- This fallback is scoped to **transient** DB failure only — it must not be used to
  silently mask a `relation "<slug>" does not exist` error in production indefinitely.
  That specific error indicates a missing migration or deploy defect, not a transient
  outage; see [0010](0010-cms-force-dynamic-and-migration.md) for the migration
  requirement this fallback is not a substitute for.
- Revisit if Payload's Local API gains a native retry/circuit-breaker so this
  catch-and-default shape's transient-outage handling can be pushed down into the
  client library rather than reimplemented per data-access function.
