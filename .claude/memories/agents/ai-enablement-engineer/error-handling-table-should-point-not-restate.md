---
id: error-handling-table-should-point-not-restate
agent: [ai-enablement-engineer]
trigger: [command error-handling table nearly duplicates dispatched agent's own table, drift risk]
rule: When a command's error-handling table restates most of a dispatched agent's own rows nearly verbatim, slim it to the rows that are genuinely command-level plus one pointer row naming the agent's.
evidence: [NA-7]
uses: 0
status: active
---

## Why

The command's own dispatch step already surfaces the agent's return verbatim, so restating 8 of 9
rows was pure duplication risk with no reader benefit.
