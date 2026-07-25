---
id: react-inline-style-serialization-format-for-rtl-assertions
agent: [web-engineer]
trigger: [getAttribute style assertion fails, opacity:1 vs "opacity: 1", custom-property valued style]
rule: 'React''s inline `style` prop serializes to the DOM''s `style` attribute with a space after each colon and a trailing semicolon per declaration (`"opacity: 1; transition: opacity .2s;"`), NOT the.'
evidence: [NA-33]
uses: 0
status: active
---
