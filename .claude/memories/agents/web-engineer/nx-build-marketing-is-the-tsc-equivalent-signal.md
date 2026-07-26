---
id: nx-build-marketing-is-the-tsc-equivalent-signal
agent: [web-engineer]
trigger: [no typecheck target for marketing, pnpm nx build marketing as real type-check signal]
rule: '`pnpm nx build marketing` is the real `tsc`-equivalent signal for this app, since no repo `typecheck` target exists — run it every story that touches `.tsx`, even when test/lint are both green.'
evidence: [NA-16, NA-30, NA-32, NA-33, NA-34, NA-36, NA-37, NA-69, NA-71]
uses: 0
status: active
---
