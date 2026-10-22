# Defect variant — `WORK_KIND=defect` drives the ladder via `systematic-debugging`

<!-- notation: `:=` define, `->` leads-to, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

Loaded by `refs/principal-engineer-playbook.md` **only when `WORK_KIND=defect`**. Activation keys
off `WORK_KIND=defect`, NOT `TRIAGE=lightweight` — a lightweight _feature_ keeps the normal ladder.

**Exception to the playbook's orchestrator rules:** on this path YOU load `systematic-debugging`,
and phases 1–2 may read code and run the reproduction — finding the bug is the work they do. From
phase 3 on, the normal rule returns: domain agents write every test and fix.

**Confirm `systematic-debugging` is invocable before phase 1.** It is a global superpowers skill,
intentionally absent from the plugin's `skills-manifest.md` / `skills-map.yml` (not stack-gated) —
that absence is by design. Genuinely uninvocable → **STOP** (`blocked`); never skip the phases.

| Playbook step | Feature path (default) | Defect path |
| --- | --- | --- |
| Step 2 (derive tasks) | agent-tagged task list from spec/plan/story | **replaced** by phase 1 (reproduce) + phase 2 (root-cause) — these _discover_ the work |
| Step 3 (branch) | `feat/<STORY-KEY>` | `fix/<STORY-KEY>` |
| Step 4 (domain dispatch) | agents write feature code | **replaced** by phase 3 (failing regression test) + phase 4 (fix + verify), each written by **dispatching the owning Active domain agent** |
| Step 5 (push/verify) | per-phase push + silent-failure STOP | **unchanged** — after each debugging-phase commit |
| Step 6 (QA loop) | QA playbook inline | **unchanged**; QA Step 7 uses the defect regression-evidence contract (`refs/ac-verification.md`) |
| Step 7 (PR) | `feat` PR | `fix` PR, `fix` type |

## The 4 phases

1. **Reproduce.** YOU establish the failing condition from the Bug's **Steps to Reproduce / Actual
   Result**. No domain agent yet. Reproduction impossible → **STOP / `blocked`** — never guess a fix.
2. **Root-cause / isolate.** Identify the owning file(s)/domain → which Active agent owns phases 3–4.
3. **Failing regression test.** Dispatch the owning agent (in `$WORKTREE`, commit not push) to add a
   test that **FAILS** against current `<BASE-BRANCH>` behaviour and pins the bug.
4. **Fix + verify.** Dispatch the owning agent to make that test **PASS**, then run the quality gate.
   Several domains → sequentially in ladder order (database-administrator → platform-engineer →
   sync-engineer → web-engineer → mobile-engineer), one at a time, on the single `fix/` branch;
   `ai-enablement-engineer` may come anywhere but still runs alone.

The phase-3 commit (test, no fix) and HEAD (fix) are QA Step 7's before/after evidence points.
Steps 0, 1, 3, 5, 6, 7, 8 run as written; a Bug always carries `LIGHTWEIGHT=true`.
