# QA quality-gate runner

Executed by a dispatched `general-purpose` subagent, and — only on the orchestrator's
inline-fallback path — by the orchestrator itself. Written in the third person for that reason:
never address "you, the subagent", and never depend on a value the orchestrator does not hold.

Inputs, all passed in the dispatch prompt: `<STORY-KEY>` `<WORKTREE>` `<NX_CACHE_DIRECTORY>` `<BRANCH_PREFIX>`

## Procedure

1. Sync the worktree:

```bash
git -C "$WORKTREE" fetch origin <BRANCH_PREFIX>/<STORY-KEY> && git -C "$WORKTREE" merge --ff-only origin/<BRANCH_PREFIX>/<STORY-KEY>
```

2. **Assert `$WORKTREE` is clean before running the gate.** The gate runs in the shared,
   persistent `$WORKTREE` where an earlier fix-round agent may have left uncommitted or untracked
   files behind (e.g. a forgotten `git add` of a new source file) — the gate would then pass
   against a tree that isn't actually what got pushed, a false green.

```bash
[ -z "$(git -C "$WORKTREE" status --porcelain)" ] \
  || { echo "STOP: \$WORKTREE has stray uncommitted/untracked files before the quality gate — $(git -C "$WORKTREE" status --porcelain)"; exit 1; }
```

A non-empty result is NOT a stop here — capture it verbatim into `Stray files:` below and let the
orchestrator STOP; never silently clean it yourself.

3. Run the quality-gate commands from `.claude/project/project-context.md` (Tooling + Quality
   Gate) **inside `$WORKTREE`** (`cd "$WORKTREE"` first — never the primary checkout), with the
   shared Nx cache exported so the gate run hits the warm cache (spec §3):

```bash
export NX_CACHE_DIRECTORY="$NX_CACHE_DIRECTORY"
cd "$WORKTREE"
# ... run the project-context Tooling + Quality Gate commands here ...
```

4. If the change touched infra, also run the infra build with the stage flag from project-context
   (still inside `$WORKTREE`).

5. Capture each command's exact string and its verbatim final status line(s) — never paraphrase.

## Gate realism

> Treat the project-context quality-gate commands as a real gate: the test command may run
> `.ts` via a transpiler and pass THROUGH type errors. Also confirm no compiled `.js` shadows
> source — a green test suite does not prove
> the deployed bundle is correct (consult the Step 1 pre-review scan of `.claude/memories/reviews/*.md`
> for prior findings on this domain).

## Return — return ONLY this block, nothing else. Cap 2,000 B.

Return contract, **verbatim**:

```text
Gate: pass | fail
Commands: <one line per command actually run, exact string>
Evidence: <verbatim final status line(s) per command, truncated to 1,200 B — never paraphrased>
Failing workspace: <path or nx project name | none>
Owning agent: <agent-name from the project-context workspace->agent table | none>
Error: <first 400 B of the failing command's stderr, verbatim | none>
Stray files: <git status --porcelain output | none>
```

```text
never -> paste a full log, a full test run, or any file's contents into the return
never -> dispatch an agent from here                       # one-level nesting limit, ADR-0012
never -> assert a pass without Evidence                    # verification-before-completion
Evidence over 1,200 B -> truncate and append "…[truncated]" ; do NOT split across return fields
whole block over 2,000 B -> truncate `Commands:` first, then `Evidence:`; never drop a key
```
