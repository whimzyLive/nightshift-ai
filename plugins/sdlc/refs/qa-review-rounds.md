# QA review rounds — parallel checks and resumed re-review

<!-- notation: `:=` define, `->` leads-to, `|` first-match-wins alternative, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

Loaded by `refs/qa-engineer-playbook.md` Steps 1, 4, 6 and 7 (Story mode). Diff mode and the
`/review-fix` entry keep the serial order — they have no gate/AC pass to overlap.

## One round = review ‖ gate ‖ AC on the same HEAD

```text
ROUND_HEAD := git rev-parse origin/<BRANCH_PREFIX>/<STORY-KEY>
dispatch in ONE message, all three in the background:
  reviewer   := Step 1 dispatch (default model — never Sonnet)
  gate       := Step 6 offload, model: "sonnet"
  verifier   := Step 7 offload, model: "sonnet"
reviewer prompt also says: "Read-only. Do not run builds, tests, typecheck or containers —
  the quality gate owns every test run (parallel runs collide on shared ports and databases)."
wait for all three -> triage (Step 2) uses the reviewer's findings; Steps 6/7 consequences apply
  to the gate/verifier blocks as written
```

Gate and verifier results describe `ROUND_HEAD` only:

```text
any fix commit pushed this round (HEAD != ROUND_HEAD) -> gate + verifier results are stale;
  the next round re-dispatches both alongside the re-review
no fix this round (review clean, gate pass, verifier met) -> results stand -> Step 5, then Step 8
gate fail or Unmet only (review clean) -> Step 3 fix for that error, then the next round: gate +
  verifier re-dispatched (QA Steps 6-7 "rerun") alongside a resumed reviewer on that fix diff
```

## Re-review — resume the same reviewer (Step 4)

The reviewer that raised the findings knows why it raised each one, so it checks the fixes.

```text
PREV_HEAD := ROUND_HEAD of the round that produced the findings
resume := SendMessage(<that reviewer instance>,
  "Fixes for your findings are pushed. Review ONLY PREV_HEAD..HEAD:
   1. for each finding you raised: fixed | not fixed | partially fixed, one line why
   2. any NEW Critical/Important issue the fix diff introduces
   Same read-only rule. Same severity scale.")
fresh full review (Step 1 dispatch over BASE_SHA..HEAD) instead WHEN
  | the reviewer cannot be resumed (SendMessage fails, or a session boundary) — a reviewer that
    has merely returned its findings IS resumable; that is the normal case
  | the fix diff is large: `git diff --shortstat PREV_HEAD..HEAD` > 150 changed lines
  | the fix diff touches a file none of the findings named
  | the resumed review reports a NEW Critical
loop until no Critical/Important and no open AC gap; Minor -> report only
```

Record each round's mechanism for Step 8: `Re-review: resumed <N> / fresh <N>`.
