---
description: Generate and maintain this repo's public docs surface via the doc-type registry and the per-repo docs manifest. v1 ships the `sync` mode — diff-drives deterministic regeneration of frontmatter-driven reference docs + `llms.txt`, and drafts gated how-to refreshes — behind the knowledge-engineer agent (refs/docs-pipeline.md), with the founder-confirmation gate at this command layer. `release`/`seed`/`audit`/`distill` are not-yet-implemented stubs (see Epic NA-50).
---

## Modes (dispatched from `$ARGUMENTS`)

| Invocation                       | Mode     | v1 status                                                       |
| -------------------------------- | -------- | --------------------------------------------------------------- |
| `/sdlc:docs sync <STORY-KEY>`    | **sync** | **In scope — this story**                                       |
| `/sdlc:docs release <version>`   | release  | Not yet implemented (see Epic NA-50) — clean stub, not an error |
| `/sdlc:docs seed <type> [topic]` | seed     | Not yet implemented (see Epic NA-50) — clean stub, not an error |
| `/sdlc:docs audit [--dry-run]`   | audit    | Not yet implemented (see Epic NA-50) — clean stub, not an error |
| `/sdlc:docs distill`             | distill  | Not yet implemented (see Epic NA-50) — clean stub, not an error |

## Argument validation

Parse `$ARGUMENTS` into `<mode>` (the first token) and the mode's remaining args. Apply, in order:

1. **Empty `$ARGUMENTS`** → STOP with the usage message:
   `usage: /sdlc:docs sync <STORY-KEY>  (release|seed|audit|distill land in later stories)`.
2. **Unrecognised first token** (not one of `sync`/`release`/`seed`/`audit`/`distill`) → STOP with
   the same usage message.
3. **Recognised future-mode token** (`release`/`seed`/`audit`/`distill`) → print
   `mode "<mode>" is not yet implemented (see Epic NA-50)` and exit cleanly. Not an error, not a
   STOP — a deliberate stub so the surface is stable before the modes land.
4. **`sync` with a missing or malformed story key** — the story key must match
   `^[A-Z][A-Z0-9]*-[0-9]+$` (e.g. `NA-52`). If the key is absent or fails the regex → STOP with the
   usage message. This is a **usage STOP** (a caller error), distinct from the manifest-absent
   silent no-op below.

## `sync <STORY-KEY>` — shared pipeline split across the dispatch boundary

The procedure — the two-phase dispatch split, the deterministic regen algorithm, the voice/format
resolution chain, the `source:` refresh convention, and the no-op/change-gate semantics — is
defined once in `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md`; this command owns only the flow
around the founder-confirmation gate (a dispatched subagent cannot itself pause for it), the
argument validation above, and the gates below that decide whether `knowledge-engineer` is
dispatched at all.

1. **Manifest gate (AC5).** Resolve `.claude/project/docs-manifest.md`. If **absent** →
   **silent no-op**: no branch, no dispatch, no PR, no error, **no stdout** — exit cleanly (exit
   0). This is the zero-setup-cost guarantee for repos that declined the `/init` docs opt-in, and
   is deliberately distinct from a usage STOP (which does print a message). Do not dispatch
   `knowledge-engineer` in this case.

2. **Resolve the story branch (v1 diff source).** `sync` never depends on the currently-checked-out
   branch:

   ```bash
   git fetch origin --quiet
   # Resolve the story branch: feat/<STORY-KEY> preferred, fix/<STORY-KEY> fallback.
   STORY_BRANCH=""
   for cand in "feat/<STORY-KEY>" "fix/<STORY-KEY>"; do
     git rev-parse --verify --quiet "origin/$cand" >/dev/null && { STORY_BRANCH="origin/$cand"; break; }
   done
   ```

   - **Neither `origin/feat/<STORY-KEY>` nor `origin/fix/<STORY-KEY>` exists** → emit the explicit
     WARNING (never a silent clean exit that reads as success):
     `WARNING: no story branch (feat|fix)/<STORY-KEY> found on origin. v1 sync is branch-diff-only; post-merge sync (diffing the merged commit range) is deferred to NA-55. Nothing regenerated.`
     — then exit. Do not dispatch `knowledge-engineer` in this case.

3. **Dispatch `knowledge-engineer` Phase 1 (compute & draft, writes nothing).** Pass it
   `STORY_BRANCH`, `<BASE-BRANCH>` (from project-context), and the story key. Per
   `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md` §2/§3, phase 1 computes `CHANGED_FILES` +
   `CHANGED_DIFF`, resolves affected rows, produces the deterministic regen content for the `auto`
   rows + `llms.txt`, drafts narrative how-to refreshes via `writing-docs`, and returns all of it
   to this command layer.

4. **Founder-confirmation gate (command layer, in-session, between the two dispatches):**
   - Present the deterministic regen summary (informational — auto rows are not gated; they were
     already computed, not yet written) and each narrative how-to draft (gated). Wait for explicit
     founder confirmation on the narrative drafts — identical discipline to `/sdlc:analyze`'s apply
     gate and `commands/adr.md`'s founder-confirmation gate: no inline auto-apply path.
   - The founder may accept, edit, or reject each narrative draft.
   - **The gate is skipped when there are zero narrative drafts** — proceed straight to phase 2
     with the deterministic content only.

5. **Dispatch `knowledge-engineer` Phase 2 (write confirmed, fresh dispatch).** Hand it the
   deterministic content **and** the founder-confirmed narrative drafts **verbatim** (inline or via
   session temp-dir files referenced by path, per `${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh`) —
   never re-derived. Phase 2 checks out the branch (see Branch/PR naming below, cut from the story
   branch head, not `<BASE-BRANCH>`), writes the deterministic regen + `llms.txt` + confirmed
   narrative drafts under their manifest-resolved `target-path`s, then — **only if content
   changed** (`git status --porcelain` on the written target paths is non-empty, AC6) — commits via
   `conventional-commit`, pushes, and opens or updates the sync PR.

6. **Write + PR only on change (AC6).** If, after writing, `git status --porcelain` on the target
   paths is **empty** (deterministic output was byte-identical and no narrative draft was
   confirmed) → no commit, no PR, exit cleanly. Otherwise commit and **open or update** the sync PR
   (see Branch/PR naming).

## Founder-confirm-gate authority note

Auto (deterministic) rows are written **un-gated** — they are computed in phase 1 and written in
phase 2 without a confirmation step, because they are fully derived and idempotent. Narrative
(how-to) drafts are written **only after explicit founder confirmation** at this command layer. A
dispatched subagent never runs the gate itself (it cannot pause for interactive input) — this
command owns it, exactly as `commands/adr.md` does for the ADR pipeline.

## Branch/PR naming

Full contract (branch, commit, PR title/base, re-run open-or-update, diff source, control-flow
tail) is defined once in
`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#7-branch--pr-naming--control-flow`. In summary:

- Branch: `docs/sync-<STORY-KEY>`, cut from the **story branch head**
  (`origin/feat/<STORY-KEY>`, fallback `origin/fix/<STORY-KEY>`) — **not** `<BASE-BRANCH>`.
- Commit: `docs(docs): sync <STORY-KEY> reference docs` (via `conventional-commit`).
- PR title: `docs(docs): sync <STORY-KEY>`; PR base: `<BASE-BRANCH>` from project-context.
- Re-run: **open or update** — if `docs/sync-<STORY-KEY>` already exists on `origin`, check it out,
  `git reset --hard` onto the freshly regenerated state, then `git push --force-with-lease` —
  never open a duplicate PR.

## `llms.txt` format (v1 decision)

Index-only, grouped by Diátaxis quadrant, generated pages of all enabled `public:yes` manifest
rows (matching the `refs/doc-types.md` `llms-txt` registry row's `source-of-truth` cell:
`generated pages of all enabled public:yes manifest rows`). Regenerated every run (AC4), committed
only if changed (AC6). Full format decision:
`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#8-llmstxt-format-v1-decision`.

## Command control flow

After the phase-2 PR is raised, drive the review loop to convergence exactly as `/sdlc:adr` does:

```bash
/loop /sdlc:loop <PR_URL>
```

If the harness cannot nest `/loop` from inside a command, fall back to `ScheduleWakeup` to drive
`sdlc:loop`'s pass-cycle instead (same effect — the loop is the last thing the session does), then
let its final pass release. If the command hit a terminal STOP, WARNING, or no-op before a PR was
raised, release the session directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — this
covers the manifest-absent silent no-op, the story-branch-missing WARNING, a usage STOP, and a
clean "nothing changed" no-op alike (all four release without a PR; only the manifest-absent path
is silent).

## Error handling

| Scenario                                                                                          | Behaviour                                                                                                                  |
| ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `.claude/project/docs-manifest.md` absent                                                         | **Silent** no-op — no branch, no dispatch, no PR, no error, **no stdout** (AC5). Distinct from a usage STOP, which prints. |
| Empty `$ARGUMENTS` / unrecognised first token                                                     | Usage STOP (prints the usage message).                                                                                     |
| `sync` with missing/malformed story key (fails `^[A-Z][A-Z0-9]*-[0-9]+$`)                         | Usage STOP (prints the usage message).                                                                                     |
| Recognised future-mode token (`release`/`seed`/`audit`/`distill`)                                 | Print "mode not yet implemented (see Epic NA-50)" and exit cleanly — not an error.                                         |
| `sync` but no `origin/feat/<STORY-KEY>` or `origin/fix/<STORY-KEY>` (post-merge / never-branched) | Emit the explicit WARNING (v1 is branch-diff-only; post-merge deferred to NA-55); exit **without** a silent success.       |
| `refs/doc-types.md` unreadable/malformed                                                          | Surface the failure and STOP — never regenerate from a partial registry.                                                   |
| Manifest present but no enabled `sync`-triggered row affected, and `llms.txt` unchanged           | Clean no-op — no commit, no PR (AC6).                                                                                      |
| Deterministic regen produced byte-identical output and no narrative draft confirmed               | No commit, no PR (AC6) — write phase detected an empty `git status --porcelain`.                                           |
| Founder rejects all narrative drafts but deterministic content changed                            | Still commit + PR the deterministic regen (AC6 — content changed).                                                         |
| Story branch diff yields no changed files                                                         | Only `llms.txt` is (re)generated; commit/PR only if it changed.                                                            |
| `gh` / `raise-pr.sh` failure                                                                      | STOP and surface — the write is on a branch and reviewable; never leave a raised-but-broken state silently.                |

Mode + args:
$ARGUMENTS
