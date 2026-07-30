---
description: Remove what a benchmark sweep left behind — draft PRs, bench branches, worktrees and scratch Jira issues
---

Clean up a benchmark ticket's run set.

This command receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness — use it directly.

## Arguments

- `<TICKET>` — the **source** ticket the sweep ran against, not a scratch key.

## Steps

1. Show what would be removed. This step only reads.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.py" --ticket <TICKET> --repo .
   ```

2. Show the founder the plan verbatim and **stop**. Do not summarise it — the Jira issue list is
   the part that cannot be undone, and a summary is where a wrong key hides. Ask for explicit
   confirmation to proceed.

   Two things to call out if present:
   - Any pull request listed as `READY, not draft`. A benchmark PR should never have left draft;
     say so, because it means the guard was bypassed or the PR is not ours.
   - An empty twin list alongside a non-empty branch list. That means the branches came from
     approaches that write no Jira, which is normal — or that the label query failed, which is not.

   Twin issues are listed as **KEPT**. That is deliberate: they carry hand-set story points acli
   cannot write back, so deleting one destroys setup the founder has to redo. Their `feat|fix/`
   branches and PRs are what must go, and those are cleared. If a founder asks why the twins
   survived, that is the reason.

3. Only after explicit confirmation:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.py" --ticket <TICKET> --repo . --confirm
   ```

4. Report the per-item log. Lines beginning `FAILED` are not fatal to the rest of the run, but each
   one is something still on the server or on disk — list them individually rather than reporting a
   count.

## What is deliberately not deleted

Twin Jira issues — see above. And `docs/benchmarks/<TICKET>/**` — the run records, transcripts and reports. Those are the result of
the sweep, not its residue. Deleting them would throw away the measurement the sweep was for.
