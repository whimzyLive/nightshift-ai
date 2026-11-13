# AC and plan verification

Executed by a dispatched `general-purpose` subagent, and — only on the orchestrator's
inline-fallback path — by the orchestrator itself. Third person, for that reason: never address
"you, the subagent", and never depend on a value the orchestrator does not hold.

Inputs, all passed in the dispatch prompt: `<STORY-KEY>` `<WORKTREE>` `<BRANCH_PREFIX>` `<BASE_SHA>` `<WORK_KIND>`

## Procedure

Apply `verification-before-completion`. Produce line-by-line checklists, each item confirmed with
evidence (git log, file existence, or test output) — no item checked off on assertion alone:

1. **Every plan task** → has a corresponding commit/file/test. Source the `checklist`-mode slice
   when the orchestrator supplies one; read the whole plan doc only on `GRAMMAR=unmatched`. With no
   plan doc on the full path, the tasks are the `## Implementation tasks` lines of
   `docs/superpowers/specs/<STORY-KEY>.md` on the branch. _(Full path only. On the lightweight path
   there is neither — skip this checklist; the AC checklist below is the completion contract.)_
2. **Every acceptance criterion** on the Jira story → is met by code that exists on the branch,
   with the specific evidence (handler/test/file) named. _(Always — and the primary gate on the
   lightweight path.)_
3. On `WORK_KIND=defect` — apply the **Defect regression-evidence contract** below IN FULL.
3a. **Every Dev Note** on the story → `followed` (name the code that follows it) or `deviated` with
    the reason recorded in the spec, plan, or a commit body. A deviation with no recorded reason is
    `unmet`. **Every Design row** the story names → the UI that implements it exists on the branch
    (name the component/page path). With `Design check` unset, visual fidelity is the reviewer's
    judgement, not this checklist. With it set, a Design row is `met` only with evidence the check
    passed for that row's board (below).
        Every Design row must name a final board (`scripts/design-kind.sh <index.md> <board>` -> `KIND=final`, or `unknown` for a pre-kind index); a draft -> `unmet` (`Design <n>: names a draft board`). Every plan row of the story (`docs/design/<slug>/component-plan.md`, `refs/component-plan.md`) is honoured: the screen uses the row's component, no local copy of it exists -> `met` with the usage path; a copy -> `unmet`.
    Both lists come from the story description (`refs/design-references.md`); a story whose Dev
    Notes and Design are `None` emits neither line type.
4. Read the range:

```bash
git -C "$WORKTREE" fetch origin <BRANCH_PREFIX>/<STORY-KEY>
git -C "$WORKTREE" log ${BASE_SHA}..origin/<BRANCH_PREFIX>/<STORY-KEY> --oneline
```

5. Per unmet AC/task id → resolve the owning agent from the project-context workspace→agent table.

## Design check evidence

The verifier reads the check's report FILE in `$WORKTREE`; it needs no extra input and nothing the
orchestrator must relay, so a truncated gate `Evidence` can never hide a board.

```text
Design check := project-context Tooling row `Design check`; unset | empty -> this section is off, Design lines stay "implementing UI exists"
REPORT := $WORKTREE/<path> where <path> := project-context Tooling row `Design check report` | `.tmp/design-check/report.txt`   # refs/design-references.md Design check
KEY := repo-relative `docs/design/<slug>/<File column path>` of the board's page row in that feature's index.md
       # e.g. docs/design/clients-and-contacts/pages/b8221b8f-….html
Design row -> KEY: a full `docs/design/<slug>/pages/<file>` path -> that row | a bare `pages/x.html` -> the row in the story's resolved design(s) | a render png -> the page row whose Render column is it | an index Title -> its row
  bare path | png | Title matching MORE than one row (a Title is the dc name and can repeat) or in more than one resolved design -> `unmet — design check: ambiguous (<candidate KEYs>)`; never first-match
Design check set AND a Design row names a board -> `Design <n>: met` needs ALL of:
  the implementing UI path exists
  REPORT exists AND its first line, parsed by fields (not an exact string), has verdict `pass`, `sha` == `git -C "$WORKTREE" rev-parse HEAD`, and `dirty` absent or `false`; other fields are ignored
  REPORT has a line `<KEY> pass`
REPORT missing | sha != HEAD | `dirty=true` | first line `fail` | `<KEY> fail` -> `unmet — design check: <missing | stale | dirty | failed>` (`dirty=true` -> `dirty`); Owner = the agent owning the UI path
`<KEY> not-checked <ticket>` (an allowance, carries a ticket)
  -> `Design <n>: not-checked — <KEY> <ticket>`; NOT `met`, NOT `unmet`, NOT in `Unmet`/`Owner`; listed on `Design not checked:` as `<KEY> <ticket>`; a Design row is the story's OWN board, so it is treated like `uncovered`: QA asks once, then it blocks `clean` (qa-engineer-playbook Step 7)
  not-checked lines for boards no story Design row names are not verified here: the verifier ignores them
REPORT valid but no line for KEY (no ticket; also what a nothing-affected run yields)
  -> `Design <n>: uncovered — <KEY>`; NOT `met`, NOT in `Unmet`/`Owner`; listed on `Design not checked:` as `<KEY> uncovered`; QA asks once, then it blocks `clean` (qa-engineer-playbook Step 7)
met -> append `; check <REPORT path>` to the Design line
the verifier never runs the check and never judges pixels by eye; the check does
```

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
Dev Note <n>: followed | deviated | unmet — <evidence | recorded reason>   # one per Dev Note; none when "None"
Design <n>: met | unmet — <implementing path>[; check <report path>] | not-checked — <KEY> <ticket> | uncovered — <KEY>   # one per story Design row; none when "None"
Regression evidence: fail-before <sha> / pass-after <sha> | n/a     # defect path only
Design not checked: <KEY ticket | KEY uncovered>, ... | none          # not-checked + uncovered rows; not Unmet
Unmet: <comma-separated AC/task/Dev Note/Design ids | none>
Owner: <id>=<agent-name>, ...  | none                               # owning agent per unmet id
```

```text
never -> paste the plan doc, a test log, or a diff into the return; name the path, not the content
never -> dispatch an agent from here
never -> mark an AC `met` on assertion; every `met` names a path, a test, or a sha
never -> open design pages to judge pixels; a Design line checks the implementing UI exists, plus the design check evidence when `Design check` is set
a line over 250 B -> shorten the evidence pointer, never drop the line
whole block over 4,000 B -> shorten evidence pointers; never drop an AC line, never drop the `Unmet` field
```
