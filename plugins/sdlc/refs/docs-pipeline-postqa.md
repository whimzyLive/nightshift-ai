# Docs pipeline — post-QA inline dispatch variant (§§25–26)

**Mode-specific slice for the Principal Engineer playbook's Step 6.5** (the post-QA inline-sync
dispatch that folds a docs regen into the impl PR) — also the general dual diff-source selection
rule standalone `sync` uses. Read together with the shared foundation slice, `docs-pipeline-core.md`
(§§1–9) — this slice does not restate the manifest gate, the two-phase dispatch split, or the
deterministic regen algorithm, it only points back to them. **Note:** the merged-commit source
(§26) reuses the `PROJECT_KEYS`-scoped story-key regex defined in `docs-pipeline-release.md` §10 —
a pre-existing cross-mode dependency inherited from the pre-split monolith, not introduced by this
split. The post-QA dispatch itself (§25) never reaches that code path (its story branch always
exists), so a Step 6.5 dispatch reading only core + this slice is unaffected; a standalone `sync`
falling onto the merged-commit path needs `docs-pipeline-release.md` §10 too.

## 25. Post-QA inline dispatch variant

`sync` composes into a run that **already owns** a story branch + one PR — the Principal Engineer
playbook's **Step 6.5**, fired after QA returns `clean` and before the PR is opened. Standalone
`sync` (`docs-pipeline-core.md` §7) is **wrong** for that context: it cuts its own `docs/sync-<KEY>` branch, runs a
founder-confirm gate, and raises its own PR. This **inline post-QA variant** keeps the regen but
strips the standalone control flow. Its **four** divergences from standalone `sync`, each with the
reason it exists:

1. **No `docs/sync-<KEY>` branch — writes on the story branch in `$WORKTREE`.** The orchestrator
   hands the agent the live `$WORKTREE` (checked out at `<BRANCH_PREFIX>/<STORY-KEY>`) and
   `$NX_CACHE_DIRECTORY`, exactly as Step 4 / QA-Step-3 domain dispatches do. The agent does **not**
   check out or cut any branch. _Reason:_ docs must land on the impl branch (AC2); a separate branch
   would need a separate PR.
2. **Single dispatch, no founder-confirm gate.** The two-phase compute→gate→write split (`docs-pipeline-core.md` §2) exists
   only to host the founder-confirm gate across a dispatch boundary. AC2 removes that gate — PR
   review is the sign-off — so the variant is a **single dispatch** that computes **and** writes the
   deterministic regen + `llms.txt` **and** the narrative how-to refreshes in one pass. The how-to
   drafts are written un-gated and reviewed in the impl PR. _Reason:_ a dispatched subagent cannot
   pause for interactive input; with the gate removed there is nothing to split across, and the
   human review moves to the PR.
3. **Commit-only; the orchestrator pushes.** The agent commits the docs changes via
   `conventional-commit` onto `<BRANCH_PREFIX>/<STORY-KEY>` and returns; the orchestrator pushes and
   runs the same push / primary-checkout guard as playbook Step 5. _Reason:_ matches the
   `domain-agent-handoff.md` "agent commits, orchestrator pushes" contract every in-playbook
   dispatch obeys — the agent's self-raise-PR behaviour applies only to **standalone**
   `/sdlc:docs`.
4. **Raises no PR.** Step 7 folds the docs commit into the impl PR. _Reason:_ AC2.

**Diff source handed in, not resolved here.** The playbook passes the **story-branch-vs-base** source
explicitly — `origin/<BASE-BRANCH>...<BRANCH_PREFIX>/<STORY-KEY>` (§26) — because at Step 6.5 the
branch always exists. The variant never runs §26's merged-commit selection.

**Everything else is `docs-pipeline-core.md` §§1–6, verbatim.** The deterministic regen algorithm (§3), the `source:` how-to
convention (§5), the affected-row resolution (§3), the manifest gate (§1), and the change-gate
(commit only if `git status --porcelain` on the written target paths is non-empty, §6) are
**unchanged** — the variant reuses them and never restates them. A no-source-change re-run commits
nothing. The failure classification (which failures WARN vs STOP) is a **playbook-layer** decision —
see `refs/principal-engineer-playbook.md` Step 6.5; this ref defines only the dispatch shape.

## 26. Dual diff source + selection rule

`sync` derives `CHANGED_FILES` / `CHANGED_DIFF` from one of **two** sources, so it works both before
and after the story branch merges:

| Diff source | `CHANGED_FILES` / `CHANGED_DIFF` derivation | Used when |
| --- | --- | --- |
| **story-branch-vs-base** (existing, NA-52) | `git diff [--name-only] "origin/<BASE-BRANCH>...$STORY_BRANCH"` — three-dot range, remote-tracking base, after `git fetch origin --quiet` | The story branch **exists on origin** (`origin/feat/<STORY-KEY>` or `origin/fix/<STORY-KEY>`). The **post-QA phase (§25) always selects this** — the branch is present and unmerged. |
| **merged-commit** (NEW, this story) | Locate the commit(s) on `origin/<BASE-BRANCH>` carrying `<STORY-KEY>`, then `git diff [--name-only] "<sha>^..<sha>"` (see below) | The story branch is **absent on origin** — a post-merge (squash-merged, branch deleted) or never-branched standalone `sync`. |

### Selection rule (deterministic, no ambient input)

1. Resolve `STORY_BRANCH` (`docs-pipeline-core.md` §2 step 2 / `commands/docs.md` step 2): `origin/feat/<STORY-KEY>`
   preferred, `origin/fix/<STORY-KEY>` fallback.
2. **`STORY_BRANCH` resolved** → **story-branch-vs-base** source (unchanged v1 behaviour).
3. **Neither branch exists on origin** → **merged-commit** source (this replaces the former
   WARNING-and-exit stub).

The **post-QA phase (§25)** never reaches step 3 — it passes story-branch-vs-base explicitly.

### Merged-commit source — precise definition

The story branch is gone, so the diff comes from the landed commit(s) on base:

1. **Locate** the commit(s) on `origin/<BASE-BRANCH>` whose subject **or** body carries
   `<STORY-KEY>`, using the **`PROJECT_KEYS`-scoped alternation regex** from
   [`docs-pipeline-release.md` §10's Story-key extraction](docs-pipeline-release.md#story-key-extraction) (`\b(?:KEY1|KEY2|…)-[0-9]+\b`) — **never** the
   loose `[A-Z][A-Z0-9]*-[0-9]+` matcher (it false-positives on `UTF-8`, `SHA-1`, per `docs-pipeline-release.md` §10). Scan
   `git log origin/<BASE-BRANCH>` after `git fetch origin --quiet`.
2. **Diff derivation.** This repo squash-merges (`gh pr merge --squash`), so a story lands as a
   **single** commit with **one** parent: `CHANGED_FILES=$(git diff --name-only "<sha>^..<sha>")`,
   `CHANGED_DIFF=$(git diff "<sha>^..<sha>")`. For a true merge commit (two parents) use the
   first-parent form `"<sha>^1..<sha>"`.
3. **Zero commits match** `<STORY-KEY>` on base → **STOP with an explicit error**
   (`cannot locate a merged commit for <STORY-KEY> on origin/<BASE-BRANCH> — nothing to diff`),
   never a silent no-op. "The branch is gone AND no landed commit references the key" is a real
   failure and must be visible, not collapsed into the benign "docs already current" path.
4. **Multiple commits match** (the story landed across several merges — e.g. a follow-up fix) → diff
   the **union** of each matching commit's `<sha>^..<sha>` file/hunk set, mirroring `docs-pipeline-release.md` §10's
   "de-duplicated union across records".

`git fetch` failure, or an unresolvable `origin/<BASE-BRANCH>`, is a **STOP** on this path — exactly
as the shared manifest gate (`docs-pipeline-core.md` §1's base-ref pre-check) already requires; never a fallthrough to
"no diff".

> **Underspecified — decision recorded (Open Question #1, adopted).** The spec flags the
> multiple-merged-commits case as the one genuinely ambiguous sub-point. The adopted default (above)
> is the **union** of each matching commit's `<sha>^..<sha>` set, mirroring `docs-pipeline-release.md` §10's union discipline —
> deterministic and complete. The alternative (most-recent commit only) risks missing files an
> earlier commit changed. If a reviewer prefers most-recent-only, change §26 step 4 and note it.
