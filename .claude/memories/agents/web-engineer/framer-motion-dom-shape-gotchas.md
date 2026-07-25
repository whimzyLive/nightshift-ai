---
id: framer-motion-dom-shape-gotchas
agent: [web-engineer]
trigger: [Framer Motion pathLength SVG assertion, motion.span unset x/y transform value, unfamiliar Motion DOM shape]
rule: For a brand-new Motion primitive whose committed DOM shape isn't obvious from source alone (SVG `pathLength`, a spring's `style.transform`, digit `stroke-dasharray`), spike it first with a throw.
evidence: [NA-69]
uses: 0
status: active
---

## Why

Two confirmed shapes worth remembering directly: Framer's `pathLength` on an SVG `motion.path`
compiles to `stroke-dasharray="X 1"` (`"0 1"` undrawn, `"1 1"` fully drawn), not a `pathLength` DOM
attribute; and a component with an unset `x`/`y` style motion value (both at default 0, e.g. before
any pointer move) serializes `style.transform` as the literal string `"none"`, not `""` or
`"translateX(0px) translateY(0px)"`.
