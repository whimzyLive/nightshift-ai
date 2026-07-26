---
id: icon-replacing-text-glyph-needs-aria-label
agent: [web-engineer]
trigger: [aria-hidden svg replacing a checkmark text glyph, GateCheck component, accessible name dropped]
rule: '`aria-hidden="true"` on an SVG that REPLACES a plain-text glyph (e.g. `''✓''` → `<GateCheck>`) silently deletes the accessible name that glyph used to provide.'
evidence: [NA-69]
uses: 0
status: active
---
