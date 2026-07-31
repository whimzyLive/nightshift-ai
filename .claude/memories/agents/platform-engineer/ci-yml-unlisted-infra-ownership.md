---
id: ci-yml-unlisted-infra-ownership
agent: [platform-engineer]
trigger: [.github/workflows/ci.yml wiring, unlisted infra path, dispatch names an out-of-table path]
rule: `.github/workflows/ci.yml` isn't a row in `project-context.md`'s workspace→agent table, but a dispatch's explicit "infrastructure" framing (or an ownership-split table in a spec) is a reasonable.
evidence: [NA-25, NA-62, NA-86]
uses: 1
status: active
---

## Why

Wire a new guard as a normal blocking step (matching the guard's own intentionally-red-until-fixed
framing, not soft-failed with `continue-on-error`) by appending one `- run: bash
plugins/sdlc/scripts/<guard>.sh` line after the last existing guard step. Verify a single-line
append via `git diff` (exactly one added line, everything else untouched) plus
`python3 -c "import yaml; yaml.safe_load(open(...))"` — catches indentation drift a visual diff
alone might miss. Also: a dispatch prompt can explicitly override the domain-agent-handoff default
("commit only, PE pushes") with a push/no-push instruction for a plan-writing-only continuation
dispatch — read the dispatch prompt's explicit instruction before defaulting to the shared protocol.
