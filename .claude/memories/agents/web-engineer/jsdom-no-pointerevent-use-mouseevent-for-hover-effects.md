---
id: jsdom-no-pointerevent-use-mouseevent-for-hover-effects
agent: [web-engineer]
trigger: [fireEvent.pointerMove silently produces NaN transform, MagneticCta test false-positive]
rule: jsdom has no native `PointerEvent` constructor at all.
evidence: [NA-69]
uses: 0
status: active
---

## Why

A test asserting `transform !== 'translateX(0px)'` also passes for a NaN transform
(`"translateX(NaNpx)..."`) — a false-positive that had been green since the component landed. Any
other component still using Pointer events inherits the same untested-by-jsdom risk.
