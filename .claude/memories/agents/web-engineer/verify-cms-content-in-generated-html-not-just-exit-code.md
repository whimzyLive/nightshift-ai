---
id: verify-cms-content-in-generated-html-not-just-exit-code
agent: [web-engineer]
trigger: [build-reaches-DB AC, static build succeeds, proving CMS content wasn't silently swallowed]
rule: Confirm a "build succeeds with populated CMS content" AC by grepping the actual generated static HTML output for real content strings (e.g. a real FAQ question).
evidence: [NA-71]
uses: 0
status: active
---

## Why

Also useful: proving an "outage fails the build" AC with a single inline env override (a bogus
`DATABASE_URL='postgres://invalid:...' pnpm nx build ...`) rather than touching the committed
`.env` — Next's dotenv loading does not override an already-set `process.env` var, so the
shell-inlined value wins for that one process and the real `.env` needs no restore step.
