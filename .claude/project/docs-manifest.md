<!--
  docs-manifest.md — scaffolded by /sdlc:init for nightshift-ai.
  This file activates /sdlc:docs: each row in the table below is one doc type that /sdlc:docs
  will generate. To deactivate a doc type, set enabled = false — that is the stable way to turn
  it off without losing the row. Deleting a row instead does NOT permanently deactivate it: a
  future re-init will offer to re-append it unless the offer was previously declined and recorded
  (see the Decline record convention below). This file may also carry, below the table, an
  optional "Voice & format" free-form section and an optional "Additional Jira project keys"
  free-form section (both described in refs/docs-manifest-template.md) — the row table itself
  remains 3-column activation data only, never generation logic, a schedule, or a runtime
  directive.
-->

| type              | enabled | target-path              |
| ----------------- | ------- | ------------------------ |
| command-reference | true    | docs/reference/commands/ |
| agent-reference   | true    | docs/reference/agents/   |
| skill-reference   | true    | docs/reference/skills/   |
| config-reference  | true    | docs/reference/config/   |
| hooks-contract    | true    | docs/reference/hooks/    |
| error-reference   | true    | docs/reference/errors/   |
| llms-txt          | true    | llms.txt                 |
| changelog         | false   | docs/changelog/          |
| release-notes     | false   | docs/release-notes/      |
| migration-guide   | true    | docs/migration-guides/   |
| tutorial          | true    | docs/tutorials/          |
| how-to            | true    | docs/how-to/             |
| integration-guide | true    | docs/integrations/       |
| concept           | true    | docs/concepts/           |
| adr               | true    | docs/adr/                |

## Additional Jira project keys

ET
