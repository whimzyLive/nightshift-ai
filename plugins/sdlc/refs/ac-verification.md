# AC and plan verification

Executed by a dispatched `general-purpose` subagent, and — only on the orchestrator's
inline-fallback path — by the orchestrator itself. Third person, for that reason: never address
"you, the subagent", and never depend on a value the orchestrator does not hold.

Inputs, all passed in the dispatch prompt: `<STORY-KEY>` `<WORKTREE>` `<BRANCH_PREFIX>` `<BASE_SHA>` `<WORK_KIND>`

## Procedure

Apply `verification-before-completion`. Produce line-by-line checklists, each item confirmed with
evidence (git log, file existence, or test output) — no item checked off on assertion alone:

1. **Every plan task** in `docs/superpowers/plans/<STORY-KEY>.md` → has a corresponding
   commit/file/test. _(Full path only. On the lightweight path there is no plan doc — skip this
   checklist; the AC checklist below is the completion contract.)_
2. **Every acceptance criterion** on the Jira story → is met by code that exists on the branch,
   with the specific evidence (handler/test/file) named. _(Always — and the primary gate on the
   lightweight path.)_
3. On `WORK_KIND=defect` — apply the **Defect regression-evidence contract** below IN FULL.
4. Read the range:

```bash
git -C "$WORKTREE" fetch origin <BRANCH_PREFIX>/<STORY-KEY>
git -C "$WORKTREE" log ${BASE_SHA}..origin/<BRANCH_PREFIX>/<STORY-KEY> --oneline
```

5. Per unmet AC/task id → resolve the owning agent from the project-context workspace→agent table.

## Defect regression-evidence contract

**On the defect path (`WORK_KIND=defect`) — ALSO require the systematic-debugging completion
contract (AC17).** A defect has **no plan doc**, so checklist 1 is skipped (as on any lightweight
path); the AC checklist (2) still applies, and **in addition** the following regression-evidence
contract MUST hold — without it, return `incomplete` (never `complete`):

1. **A regression test that FAILED before the fix and PASSES after.** Take the evidence from the
   branch's **own commit sequence**, NOT a `BASE_SHA` checkout:
   - at the **phase-3 commit** (regression test added, phase-4 fix not yet applied) the test **fails
     as an assertion** against the still-buggy behaviour;
   - at **HEAD** (fix applied) it **passes**.

   > Why not `BASE_SHA`: at develop's merge-base the test file does not yet exist, so running it
   > there fails to _compile/resolve_ rather than _assert_ — it cannot distinguish "failed because
   > the bug is present" from "failed to build". The **phase-3 commit** is the correct pre-fix point:
   > the test exists there and exercises code that compiles, failing only on the assertion the fix
   > later satisfies.

   ```bash
   # Identify the phase-3 commit (regression test added, before the fix), then show fail→pass.
   # Always inside $WORKTREE (the same one captured by the caller) — never the primary checkout.
   git -C "$WORKTREE" fetch origin <BRANCH_PREFIX>/<STORY-KEY>
   git -C "$WORKTREE" log ${BASE_SHA}..origin/<BRANCH_PREFIX>/<STORY-KEY> --oneline   # locate the phase-3 (test) commit
   git -C "$WORKTREE" checkout <phase-3-sha>          # detached, inside $WORKTREE only
   # run the regression test here: FAILS (assertion) against the still-buggy behaviour — paste output.
   git -C "$WORKTREE" checkout <BRANCH_PREFIX>/<STORY-KEY>   # back to HEAD, inside $WORKTREE
   # run the regression test here again: PASSES — paste output.
   ```

This is **in addition** to the existing lightweight ACs-as-contract fallback — the defect path
_adds_ the failing→passing regression-test requirement. (No double-verify: systematic-debugging
phase-4 is the _implementer's_ inner check that the fix works; this contract is QA's _outer_ gate
proving the regression evidence.)

## Return — return ONLY this block, nothing else. Cap 4,000 B; each AC/task line <= 250 B.

Return contract, **verbatim**:

```text
Verification: complete | incomplete
AC-<n>: met | unmet — <path:line | test name | commit sha>          # one line per AC, always
Plan task <n>: met | unmet — <evidence>                             # full path only; omitted on lightweight
Regression evidence: fail-before <sha> / pass-after <sha> | n/a     # defect path only
Unmet: <comma-separated AC/task ids | none>
Owner: <id>=<agent-name>, ...  | none                               # owning agent per unmet id
```

```text
never -> paste the plan doc, a test log, or a diff into the return; name the path, not the content
never -> dispatch an agent from here
never -> mark an AC `met` on assertion; every `met` names a path, a test, or a sha
a line over 250 B -> shorten the evidence pointer, never drop the line
whole block over 4,000 B -> shorten evidence pointers; never drop an AC line, never drop the `Unmet` field
```
