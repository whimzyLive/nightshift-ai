# Parallel fix agents — one QA fix round, disjoint domains side by side

<!-- notation: `:=` define, `->` leads-to, `|` first-match-wins alternative, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

Loaded by `refs/qa-engineer-playbook.md` Step 3 (Story mode only; Diff mode and implementation
phases stay serial). Everything not named here is Step 3 as written.

## Switch and precondition

```text
ASSERT bash ${CLAUDE_PLUGIN_ROOT}/scripts/fix-worktrees.sh enabled   # project-context Tooling `SDLC parallel fixes`; absent | anything but `enabled` = off
ELSE Step 3 as written
precondition := the repo isolates its own tests (per-worktree database name, port offset, no shared
  fixture dir): agents run tests at the same time and the plugin cannot see a shared database or port.
  Not isolated -> leave the row `disabled`.
```

## Partition

```text
owners(f) := agents of every file in finding f's listed sites, via the project-context Workspace -> agent table
|owners| == 1 -> group[owner]       # distinct agents own distinct paths: groups are disjoint
|owners| > 1  -> SEQ                # a cross-domain finding never runs beside anything
parallel round := >= 2 groups; else Step 3 as written
```

## Round

```text
PRE := git -C "$WORKTREE" rev-parse HEAD
per group g (tag := its agent name): bash ${CLAUDE_PLUGIN_ROOT}/scripts/fix-worktrees.sh add <STORY-KEY> <tag>
  -> WORKTREE= FIX_BRANCH= lines; exit 3 (no copy-on-write clone of node_modules; a full install costs
     minutes) | any other failure -> g joins SEQ, never a STOP
dispatch every remaining group in ONE message, in the background; Step 3's prompt with item 1 naming
  the group's WORKTREE and item 6 reading: "Branch <FIX_BRANCH> is checked out in <that WORKTREE>,
  forked from <BRANCH_PREFIX>/<STORY-KEY>. Commit there. Do NOT push. Do NOT touch <story WORKTREE>
  or the primary checkout."
wait (refs/qa-review-rounds.md wait rule)
per group in dispatch order: bash ${CLAUDE_PLUGIN_ROOT}/scripts/fix-worktrees.sh merge <STORY-KEY> <tag>
  | RESULT=merged           -> its commits are on the story branch
  | RESULT=conflict | dirty | error -> g joins SEQ; the story branch is untouched by it
  | RESULT=empty            -> Step 3's no-commit rule (`blocked`)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/fix-worktrees.sh remove <STORY-KEY>   # before any return, `blocked` included
each SEQ group, one at a time, on $WORKTREE: Step 3 as written, with that group's findings whole
  (a SEQ-from-conflict agent's earlier commits were discarded with its worktree)
then Step 3's post-dispatch checks once over PRE..HEAD: check-commits, `Rules applied:` per return,
  push, workspace assert; the gate runs only after this
```

## Notes

- Agent reuse: unchanged. The reuse decision is made per group exactly as today; a resumed instance
  gets the group's worktree in the Step 3 item 1 line, and the same line names `$WORKTREE` again
  when it falls back to SEQ.
- `node_modules` is cloned from the story worktree, not installed (the fix branch has the story's
  lockfile). Cost: near zero on APFS and reflink filesystems, which is where it runs; elsewhere
  `add` exits 3 and the round is sequential.
- Merge is `git cherry-pick` of the fix branch's commits in order; a conflict aborts, so a
  non-merged agent leaves nothing behind.
- Step 8: append `; parallel <N> / conflict fallback <N>` to the `Fix dispatch:` line when a round ran this way.
