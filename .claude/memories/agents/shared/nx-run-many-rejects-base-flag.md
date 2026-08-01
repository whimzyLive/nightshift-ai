---
id: nx-run-many-rejects-base-flag
agent: [platform-engineer, ai-enablement-engineer, web-engineer]
trigger: [pnpm nx run-many --base, eslint invalid option --base, next build unknown option --base, verification gate false failure]
rule: Never pass --base to `pnpm nx run-many`; it is `nx affected`-only and run-many forwards it unrecognised to eslint/next build, failing every project.
evidence: [NA-93]
uses: 1
status: active
---

## Why

`--base=<ref>` is valid on `nx affected` (it scopes the affected-project computation) but
`nx run-many` has no such flag — it silently passes the unrecognised token straight through as an
extra CLI argument to each target's underlying command. `eslint . --base=...` and
`next build --base=...` both then fail with "unknown option", which reads exactly like a real
lint/build regression across every project in the run. Confirmed on this dispatch: the same
`run-many -t lint test build typecheck` invocation without `--base` passed every target (cached).
Use `nx affected -t ... --base=<ref>` to scope by diff, and plain `nx run-many -t ...` (no `--base`)
to run everything.
