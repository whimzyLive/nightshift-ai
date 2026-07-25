---
id: full-bleed-vs-contained-section-padding-convention
agent: [web-engineer]
trigger: [double horizontal padding, section carries its own 28px plus main's px-7, full-bleed escape]
rule: Every home section either (a) uses the `left-1/2 right-1/2 -mx-[50vw] w-screen` full-bleed escape and therefore correctly needs its own horizontal padding (it opted out of `<main>`'s padding), o.
evidence: [PR#97]
uses: 0
status: active
---
