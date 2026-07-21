<!--
  docs-manifest.md — fixture B: plain repo (no contracts, no Claude artifacts, no
  reference-roots, no source/contract configured on any row). Used by
  docs-sync-fixtures.test.sh only; not a real manifest.
-->

| type              | enabled | target-path              | source | contract |
| ----------------- | ------- | ------------------------ | ------ | -------- |
| command-reference | true    | docs/reference/commands/ |        |          |
| api-reference     | true    | docs/reference/api/      |        |          |
| config-reference  | true    | docs/reference/config/   |        |          |
| cli-reference     | true    | docs/reference/cli/      |        |          |
| error-reference   | true    | docs/reference/errors/   |        |          |
| llms-txt          | true    | llms.txt                 |        |          |
