---
id: cli-output-may-have-preamble-before-json-parse-defensively
agent: [ai-enablement-engineer]
trigger: [CLI documented to return JSON array, human-readable preamble line before JSON output]
rule: Never assume a CLI's documented/skill-modeled output shape (e.g. "returns a JSON array, pipe straight to `jq`") is what actually comes out on stdout.
evidence: [NA-4]
uses: 0
status: active
---

## Why

A human-readable preamble line before JSON is a common real-world CLI pattern. Folding a
parse-failure into the connection-error message misdiagnoses a CLI-version/output-format problem as
a backend-reachability problem, sending the founder down the wrong troubleshooting path.
