# QA review rounds — exhaustive first pass, scoped re-review, round cap

<!-- notation: `:=` define, `->` leads-to, `|` first-match-wins alternative, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

Loaded by `refs/qa-engineer-playbook.md` Steps 1, 3, 4, 6 and 7. The parallel round is Story mode
only — Diff mode and the `/review-fix` entry keep the serial order (no gate/AC pass to overlap);
Round 1, Re-review and Round cap apply to every mode.

## Reviewer model

Round 1 resolves `REVIEWER_MODEL` with the script, never inline. `STORY_POINTS` comes from the Principal
Engineer playbook (triage block) or `commands/review.md` (one `refs/jira-fetch.md` "Reading story
points" probe, only when a threshold is set); a Bug is `WORK_KIND=defect`.

```bash
eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/read-review-config.sh)"
eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-reviewer-model.sh \
  --threshold "$REVIEW_MODEL_THRESHOLD" --mode <story|diff> --work-kind <WORK_KIND> --points <STORY_POINTS>)"
```

`sonnet` only when the optional `Reviewer model threshold` is set, Story mode, `WORK_KIND=feature` and
points <= threshold; every other case is `opus`. A resumed reviewer keeps its model; a fresh scoped
re-review is always `sonnet`.

## One round = review ‖ gate ‖ AC on the same HEAD

```text
ROUND_HEAD := git rev-parse origin/<BRANCH_PREFIX>/<STORY-KEY>
dispatch in ONE message, all three in the background (round 1 with the design check already red: reviewer and verifier only — "Round 1 — design check already red" below):
  reviewer   := Step 1 dispatch, model: $REVIEWER_MODEL (Step 1 "Reviewer model")
  gate       := Step 6 offload, model: "haiku"   # runs scripted commands, no judgement
  verifier   := Step 7 offload, model: "sonnet"
Design check set AND a Design row exists (the gate runs the full row this round): the verifier
  is dispatched with `DESIGN_REPORT=defer` (code, tests, Dev Notes in parallel; Design lines `pending gate`).
  After the gate hands back at ROUND_HEAD -> ONE short verifier pass, `DESIGN_REPORT=read`, Design lines only;
  its lines replace the `pending gate` lines; `Unmet`/`Owner`/`Design not checked` are the union of both passes
  still `pending gate` -> re-offload the gate once, re-read; still pending -> capped,
  `design not checked: <KEY> no valid report` on `Open (capped):`; never a fix round on its own
  no Design row | `Design check` unset -> no second pass, the verifier runs as before
reviewer prompt also says: "Read-only. Do not run builds, tests, typecheck or containers —
  the quality gate owns every test run (parallel runs collide on shared ports and databases)."
wait for all three -> triage (Step 2) uses the reviewer's findings; Steps 6/7 consequences apply
  to the gate/verifier blocks as written
wait := end the turn with no tool call; each agent's handback resumes the session
never -> wait with a shell loop (`pgrep`, `sleep`, `until`, `while`) on an agent, a commit or a
  process: `pgrep -f` matches the loop's own shell, so it runs to its cap after the agent is done
a handback is the finish -> every command the agent started has exited; nothing runs on behind it
handback while a command still runs | a "still running" return -> never wait for a follow-up notification;
  check the state yourself (branch, worktree, the command's output file), then continue or re-dispatch the remaining step
```

The same wait rule holds for every dispatch in a story run (the implementing agent, a fix round, the
docs agent), not only the round's three.

Gate and verifier results describe `ROUND_HEAD` only:

```text
any fix commit pushed this round (HEAD != ROUND_HEAD) -> the gate is stale: the next round
  re-dispatches it alongside the re-review. The verifier is re-dispatched too UNLESS all hold:
  | its last block had `Unmet: none`
  | every `met` line's evidence is a path (`path` or `path:line`) -- a test name or a sha can't be
    matched to a diff, so it forces a re-run
  | `git diff --name-only PREV_HEAD..HEAD` touches none of those paths
  -> then its last block carries forward unchanged (record `AC verify: carried` for Step 8) except Design lines, which the gate's new run re-reads (read pass above); the
  gate re-running every round still catches a fix that breaks an AC's test
no fix this round (review clean, gate pass, verifier met) -> results stand -> Step 5, then Step 8
gate fail or Unmet only (review clean) -> Step 3 fix for that error, then the next round: gate +
  verifier re-dispatched (QA Steps 6-7 "rerun") alongside a resumed reviewer on that fix diff
```

## Round 1 — one exhaustive pass (Step 1)

Findings that arrive one per round are what make a loop run 4–6 rounds. The Step 1 reviewer
prompt also says:

```text
"This is the only full review. Report EVERY Critical/Important issue now — later rounds check
 only the fix diff, so anything missed here ships as a follow-up.
 For each finding, name its CLASS (the general way it fails, e.g. 'markup that bypasses the
 sanitiser', 'unchecked tenant id') and list EVERY site in the diff where that class applies.
 Untrusted input — parsing, sanitising, escaping, URLs, file paths, SQL, auth, permissions,
 tokens, crypto — first write a threat checklist (the attack classes that apply), check each
 one, and report per class. A hand-rolled parser/sanitiser where a maintained library exists is
 itself an Important finding.
 UI changes: a duplicate of a pattern the app or the design bundle already has, a shared component
 restyled at its call site (a className override or a wrapper that re-skins it), display logic
 (formats, initials, tints, status colours) in a page, or a new shared-component file with no
 stated reason in the story -> Important."
```

Step 3 hands the fix agent the whole class with every site, never one instance: "fix the class,
then search the diff for any site the list missed".

## Round 1 — design check already red

The orchestrator holds the implementing agents' hand-backs in this session. A fresh `/review` or
`/review-fix` session has none, so round 1 there is as above.

```text
1. HAND_BACK := the full text (Note and Summary) of the LAST implementation-phase hand-back pushed to the branch
   (Story mode via /impl or /auto only)
2. RED_PATH := the design-check report path HAND_BACK names anywhere in its text, in any wording
   names none -> the project-context Tooling `Design check report` path, else the default
   `.tmp/design-check/report.txt` (refs/design-references.md Design check)
3. RED := bash ${CLAUDE_PLUGIN_ROOT}/scripts/design-check-red.sh "$WORKTREE/<RED_PATH>"
   (DESIGN_RED=yes plus one FAILING=<board line> per failing board)
   DESIGN_RED=no -> the full round above; stop here   # the hand-back and the report disagree, or the report is gone: never skip on a guess
4. DESIGN_RED=yes -> round 1 dispatches the reviewer and the verifier only, in ONE message, both in the
   background; the verifier takes `DESIGN_REPORT=defer`. The gate is NOT dispatched
5. Step 2 triage as usual, then Step 3 dispatches the fix to the agent that returned HAND_BACK, even
   when the reviewer found nothing. The fix prompt carries the reviewer's findings verbatim plus:
   `Design check: red. Report: <RED_PATH>. Failing boards:` and the FAILING lines. It names the
   `Design check (scoped)` row when set, else `Design check`, never a pasted command
6. This round counts as round 1 against MAX_REVIEW_ROUNDS. The fix commit makes HEAD != ROUND_HEAD, so
   the gate runs in the next round alongside the resumed reviewer, as the staleness rule above says
```

A clean exit still needs a passing gate on the final HEAD: step 5 always dispatches a fix, so a
round with the gate skipped never ends the run.

## Re-review — resume the same reviewer (Step 4)

The reviewer that raised the findings knows why it raised each one, so it checks the fixes.

```text
PREV_HEAD := ROUND_HEAD of the round that produced the findings
FIX_DIFF  := Story mode / `/review-fix` -> PREV_HEAD..HEAD (fix commits are pushed)
           | Diff mode -> fixes stay uncommitted: before each fix round save
             `git diff <BASE_SHA> > <tmp>/round-<N>.diff` (+ untracked files); FIX_DIFF := the change
             between round-<N>.diff and the current `git diff <BASE_SHA>`; hand the reviewer both
resume := SendMessage(<that reviewer instance>,
  "Fixes for your findings are applied. Review ONLY FIX_DIFF:
   1. for each finding you raised: fixed | not fixed | partially fixed, one line why
   2. any NEW Critical/Important issue IN FIX_DIFF
   3. a new issue in code outside the story's own diff (BASE_SHA..HEAD) -> FOLLOW-UP, not a finding
      (Critical stays Critical wherever it is)
   Same read-only rule. Same severity scale.")
resume fails (SendMessage errors, or a session boundary) -> fresh reviewer (Step 1 dispatch,
  model: "sonnet" -- always, whatever round 1 used) with the SAME scoped prompt plus the previous findings verbatim -- never a fresh
  full BASE_SHA..HEAD review
`/review-fix` -> the external comments are round 1 (no reviewer to resume): its first re-review is
  a fresh scoped reviewer as above (`sonnet`); later rounds resume that one
diff size never forces a full review -- it is still FIX_DIFF
FOLLOW-UP -> only pre-existing code outside the story's diff; never loops; QA verdict `Follow-ups:`
  line; the PR body lists it. An Important issue anywhere in the story's diff is a finding, bounded
  by the round cap -- never a follow-up, so it can never ship on a `clean` verdict
```

Record each round's mechanism for Step 8: `Re-review: resumed <N> / fresh <N>` and
`AC verify: run <N> / carried <N>`.

## Round cap (Step 4)

```text
MAX_REVIEW_ROUNDS := 3   # round 1 + two re-reviews
loop while Critical/Important open AND round < MAX_REVIEW_ROUNDS
after round MAX_REVIEW_ROUNDS with findings still open, stop review fixes, then:
  1. gate red or an AC Unmet -> fix them first (Steps 6-7 rerun, Step 3) -- these rounds do not
     count toward the cap; still red/Unmet at an unrecoverable point -> Status: blocked
  2. | any Critical open                              -> Status: blocked, reason "review cap: Critical open"
     | Important only, gate green, ACs met (Story mode) -> Status: capped, each open finding on `Open (capped):`
a Design board still uncovered or not-checked after Step 7's one ask (review may be clean) -> Status: capped, `design uncovered: <KEY>` | `design not checked: <KEY> <ticket>` on `Open (capped):`   # from Step 7, not the round cap
gate-fail / Unmet-only rounds (review clean) and the one not-checked round do not count toward the cap
```

`capped` is not `clean`: the Principal Engineer opens a **draft** PR listing the open findings and
the run never auto-merges it — a person decides (fix, or merge and file the follow-ups).
