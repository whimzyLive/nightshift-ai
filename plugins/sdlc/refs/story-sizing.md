# Story sizing

Every story pays a fixed delivery cost (gate, QA rounds, AC verification, PR, merge) whatever its points, so a decomposition that slices thin costs more than one that slices to outcomes. The bounds are project parameters.

## Bounds

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/story-sizing.sh` prints `MIN_STORY_SIZE=<n|none>` and `MAX_STORY_SIZE=<n>` from the `## Story sizing` section of `.claude/project/project-context.md`. A non-zero exit (a value outside the Fibonacci set, or min above max) is a STOP: show its message, never guess a bound.

```markdown
## Story sizing

| Token          | Value |
| -------------- | ----- |
| Min story size | `3`   |
| Max story size | `13`  |
```

| Row            | Default          | Meaning                                                                       |
| -------------- | ---------------- | ----------------------------------------------------------------------------- |
| Min story size | unset (no floor) | Soft floor, applied by the merge rule below                                   |
| Max story size | `8`              | Split ceiling: a story estimated above it is split before it is created       |

Allowed values: 1, 2, 3, 5, 8, 13. The estimate set is the Fibonacci values up to MAX. With both rows absent behaviour is exactly the historic one: ceiling 8, no floor.

## Min: the merge rule

After drafting and estimating, a slice estimated under MIN is merged with an adjacent slice of the same Epic when one qualifies. Two slices qualify only when all three hold:

- the same role;
- the same surface or entity;
- the same owner per the Workspace -> agent table in project-context.

Further conditions:

- Never merge only to reach a number: a pair that fails any test above stays separate.
- The merged story is re-estimated and must not exceed MAX; a merge that would is not made.
- A merged story is still one coherent user-verifiable outcome group; its summary names the combined outcome.
- When no slice qualifies, the small slice stays small. Never inflate an estimate to reach MIN.

## Acceptance criteria by size

| Estimate    | ACs        |
| ----------- | ---------- |
| up to 5     | 3-6        |
| 8           | up to 10   |
| 13          | up to 14   |

Above 6 ACs, group them under one sub-heading per outcome (a bold line above each group of checkboxes).

## Scope

Applies to new decompositions and refinements only. Never re-slice, merge or split an existing Jira story because the bounds changed.
