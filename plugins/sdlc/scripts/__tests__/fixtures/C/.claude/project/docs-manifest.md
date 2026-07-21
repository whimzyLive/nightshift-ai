<!--
  docs-manifest.md — fixture C: artifact repo shaped like Nightshift (a testplugin/ tree under
  a configured reference-roots entry, plus a family-resolved config-reference source). cli/error
  rows carry no source, so they stay inactive. Used by docs-sync-fixtures.test.sh only; not a
  real manifest.
-->

| type              | enabled | target-path              | source                         | contract |
| ----------------- | ------- | ------------------------ | ------------------------------ | -------- |
| command-reference | true    | docs/reference/commands/ |                                |          |
| agent-reference   | true    | docs/reference/agents/   |                                |          |
| skill-reference   | true    | docs/reference/skills/   |                                |          |
| hooks-contract    | true    | docs/reference/hooks/    |                                |          |
| config-reference  | true    | docs/reference/config/   | testplugin/refs/\*-template.md |          |
| cli-reference     | true    | docs/reference/cli/      |                                |          |
| error-reference   | true    | docs/reference/errors/   |                                |          |
| llms-txt          | true    | llms.txt                 |                                |          |

## Reference roots

reference-roots: testplugin
