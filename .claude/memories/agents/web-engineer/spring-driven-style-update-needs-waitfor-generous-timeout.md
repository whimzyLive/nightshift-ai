---
id: spring-driven-style-update-needs-waitfor-generous-timeout
agent: [web-engineer]
trigger: [whileTap spring style update not synchronous in RTL, flakes under full-suite parallel workers]
rule: A `whileTap`/spring-driven DOM style update is not necessarily reflected synchronously after `fireEvent.pointerDown`/`pointerMove` even inside RTL's `act()`-wrapped `render()`.
evidence: [NA-69]
uses: 0
status: active
---
