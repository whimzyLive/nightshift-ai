---
id: transform-on-ancestor-breaks-position-fixed-containing-block
agent: [web-engineer]
trigger: [motion.div animating y above a fixed inset-0 layer, NightSky un-pinning from scroll]
rule: A `transform`/`filter`/`perspective`/`will-change:transform` on any ancestor of a `position:fixed` element re-parents that element's containing block, un-pinning it from the viewport so it scrol.
evidence: [NA-69]
uses: 0
status: active
---
