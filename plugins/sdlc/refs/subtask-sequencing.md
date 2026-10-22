# Sub-task commit sequencing

Loaded by `refs/principal-engineer-playbook.md` **only when `SUBTASK_COUNT > 0`** (from
`pre-impl.sh`). With no sub-tasks each phase is one full-story pass with the normal commit cadence.

Sequencing happens **within** each domain phase — it never reorders or replaces the ladder:

- Iterate `SUBTASKS` in `pre-impl.sh` order (Jira `created ASC`); **never re-sort**.
- For each sub-task **whose work touches the current phase's domain**, make **≥1 commit** on the one
  `<BRANCH_PREFIX>/<STORY-KEY>` branch: `<type>(<scope>): [<SUBTASK-KEY>] <sub-task summary>`
  (`<type>` = `fix` on the defect path, `feat` otherwise; scope per the `conventional-commit` skill).
- A sub-task with no work in this phase gets **no commit here** — it lands in whichever phase owns
  its files. Across the run every sub-task lands ≥1 commit.
- No branch per sub-task, one sub-task at a time, no Jira status transitions on sub-tasks.
- Step 5: a phase advances HEAD by **one commit per sub-task it touched**; zero new commits is still
  the silent-failure STOP.
- Step 7: the PR title keeps the parent `<STORY-KEY>`; the body lists every sub-task key, written to
  `$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)/pr-body.md` and passed by `--body-file`:

```text
Implementation for <STORY-KEY>. All phases complete, review clean, quality gate passed.

Sub-tasks (implemented in fetch order, one commit per sub-task):
- <SUBTASK-KEY> — <summary>
```

Domain-agent prompt addition: the ordered `SUBTASKS` list, and "implement your phase's slice one
sub-task at a time, in that order, one commit per sub-task with the key in the message; a sub-task
with no work in your domain gets no commit in your phase."
