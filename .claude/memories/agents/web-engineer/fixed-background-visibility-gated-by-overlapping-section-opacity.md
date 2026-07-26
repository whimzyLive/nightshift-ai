---
id: fixed-background-visibility-gated-by-overlapping-section-opacity
agent: [web-engineer]
trigger: [scroll/viewport effect reported invisible on real page, position:fixed background layer, dawn tint never visible]
rule: When a scroll/viewport-driven effect on a `position:fixed` background layer is reported "invisible" on a real page (not a component in isolation), map every ancestor/overlapping section's own ba.
evidence: [NA-69]
uses: 0
status: active
---

## Why

A dawn-tint ramp reaching opacity 1 during a page's final stretch was still invisible, because that
stretch was dominated by sections with OPAQUE backgrounds painting on top of the fixed sky —
retuning the ramp range to land during transparent sections (and to still show through a translucent
footer) fixed it. A "make the opacity ramp reach 1 sooner" fix alone would have looked identical in
code review but stayed invisible in the browser.
