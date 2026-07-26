---
id: empty-targets-nx-project-registration-pattern
agent: [ai-enablement-engineer]
trigger: [registering plugins/sdlc as an Nx project, non-buildable directory in the Nx graph, nx release needs to see a root]
rule: Register a non-buildable directory (e.g. `plugins/sdlc`, `plugins/gtm`) as an Nx project purely so `nx release` can see it in the graph via a `project.json` with `"targets": {}`.
evidence: [NA-63]
uses: 0
status: active
---

## Why

`pnpm nx show project <name> --json` reports empty targets and `pnpm nx run-many -t lint test build
typecheck e2e --dry-run` lists no tasks for either root — safe, inert registration.
