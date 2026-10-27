# QA review rounds — exhaustive first pass, scoped re-review, round cap

<!-- notation: `:=` define, `->` leads-to, `|` first-match-wins alternative, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

Loaded by `refs/qa-engineer-playbook.md` Steps 1, 3, 4, 6 and 7. The parallel round is Story mode
only — Diff mode and the `/review-fix` entry keep the serial order (no gate/AC pass to overlap);
Round 1, Re-review and Round cap apply to every mode.

## One round = review ‖ gate ‖ AC on the same HEAD

```text
ROUND_HEAD := git rev-parse origin/<BRANCH_PREFIX>/<STORY-KEY>
dispatch in ONE message, all three in the background:
  reviewer   := Step 1 dispatch, model: "opus"
  gate       := Step 6 offload, model: "haiku"   # runs scripted commands, no judgement
  verifier   := Step 7 offload, model: "sonnet"
reviewer prompt also says: "Read-only. Do not run builds, tests, typecheck or containers —
  the quality gate owns every test run (parallel runs collide on shared ports and databases)."
wait for all three -> triage (Step 2) uses the reviewer's findings; Steps 6/7 consequences apply
  to the gate/verifier blocks as written
```

Gate and verifier results describe `ROUND_HEAD` only:

```text
any fix commit pushed this round (HEAD != ROUND_HEAD) -> the gate is stale: the next round
  re-dispatches it alongside the re-review. The verifier is re-dispatched too UNLESS all hold:
  | its last block had `Unmet: none`
  | every `met` line's evidence is a path (`path` or `path:line`) -- a test name or a sha can't be
    matched to a diff, so it forces a re-run
  | `git diff --name-only PREV_HEAD..HEAD` touches none of those paths
  -> then its last block carries forward unchanged (record `AC verify: carried` for Step 8); the
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
 itself an Important finding."
```

Step 3 hands the fix agent the whole class with every site, never one instance: "fix the class,
then search the diff for any site the list missed".

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
  model: "opus") with the SAME scoped prompt plus the previous findings verbatim -- never a fresh
  full BASE_SHA..HEAD review
`/review-fix` -> the external comments are round 1 (no reviewer to resume): its first re-review is
  a fresh scoped reviewer as above; later rounds resume that one
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
gate-fail / Unmet-only rounds (review clean) do not count toward the cap
```

`capped` is not `clean`: the Principal Engineer opens a **draft** PR listing the open findings and
the run never auto-merges it — a person decides (fix, or merge and file the follow-ups).
