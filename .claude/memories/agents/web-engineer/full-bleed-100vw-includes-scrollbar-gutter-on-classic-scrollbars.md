---
id: full-bleed-100vw-includes-scrollbar-gutter-on-classic-scrollbars
agent: [web-engineer]
trigger: [full-bleed band -mx-50vw w-screen, horizontal scrollbar regression on Windows/Linux Chrome]
rule: 'The full-bleed-band `-mx-[50vw] w-screen` trick is built on `100vw`, which includes the scrollbar gutter on classic (non-overlay) scrollbar platforms — fix with `overflow-x: clip` on `body`.'
evidence: [NA-32]
uses: 0
status: active
---
