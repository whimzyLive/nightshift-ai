---
id: one-shot-interval-separate-effect-for-stop-condition
agent: [web-engineer]
trigger: [setInterval effect on empty deps must stop itself once at a ceiling, race-step animation]
rule: A one-shot `setInterval` effect (deps `[]`, must stop itself once it hits a ceiling without ever restarting) needs the interval id stored in a `useRef` and cleared from a SECOND, separate effect.
evidence: [NA-34]
uses: 0
status: active
---
