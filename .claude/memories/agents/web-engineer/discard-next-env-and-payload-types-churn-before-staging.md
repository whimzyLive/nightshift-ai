---
id: discard-next-env-and-payload-types-churn-before-staging
agent: [web-engineer]
trigger: [next-env.d.ts modified after build, payload-types.ts regenerated, importMap.js churn]
rule: '`pnpm nx build`/`test` regenerate several unrelated tracked files as a side effect.'
evidence: [NA-32, NA-33, NA-36, PR#97]
uses: 0
status: active
---
