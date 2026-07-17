---
description: Generate and maintain this repo's public docs surface via the doc-type registry and the per-repo docs manifest. Ships two live modes — `sync` diff-drives deterministic regeneration of frontmatter-driven reference docs + `llms.txt` and drafts gated how-to refreshes; `release <version>` aggregates every story merged since the last tag into the manifest-enabled subset of changelog, ADR-linked release notes, and a migration-guide stub, then deterministically regenerates the doc index + `llms.txt`. Both run behind the knowledge-engineer agent (refs/docs-pipeline.md), with the founder-confirmation gate at this command layer. `seed`/`audit`/`distill` are not-yet-implemented stubs (see Epic NA-50).
---

## Modes (dispatched from `$ARGUMENTS`)

| Invocation                       | Mode        | v1 status                                                       |
| -------------------------------- | ----------- | --------------------------------------------------------------- |
| `/sdlc:docs sync <STORY-KEY>`    | **sync**    | Shipped (NA-52)                                                 |
| `/sdlc:docs release <version>`   | **release** | **Shipped (NA-53)**                                             |
| `/sdlc:docs seed <type> [topic]` | seed        | Not yet implemented (see Epic NA-50) — clean stub, not an error |
| `/sdlc:docs audit [--dry-run]`   | audit       | Not yet implemented (see Epic NA-50) — clean stub, not an error |
| `/sdlc:docs distill`             | distill     | Not yet implemented (see Epic NA-50) — clean stub, not an error |

## Argument validation

Parse `$ARGUMENTS` into `<mode>` (the first token) and the mode's remaining args. Apply, in order:

1. **Empty `$ARGUMENTS`** → STOP with the usage message:
   `usage: /sdlc:docs sync <STORY-KEY> | release <version>  (seed|audit|distill land in later stories)`.
2. **Unrecognised first token** (not one of `sync`/`release`/`seed`/`audit`/`distill`) → STOP with
   the same usage message.
3. **Recognised future-mode token** (`seed`/`audit`/`distill`) → print
   `mode "<mode>" is not yet implemented (see Epic NA-50)` and exit cleanly. Not an error, not a
   STOP — a deliberate stub so the surface is stable before the modes land. **`release` is not in
   this set** — it routes to the release contract below.
4. **`sync` with a missing or malformed story key** — the story key must match
   `^[A-Z][A-Z0-9]*-[0-9]+$` (e.g. `NA-52`). If the key is absent or fails the regex → STOP with the
   usage message. This is a **usage STOP** (a caller error), distinct from the manifest-absent
   silent no-op below.
5. **`release` with a missing or empty `<version>`** → STOP with the usage message. A **usage STOP**,
   distinct from the manifest-absent silent no-op and the no-stories-merged clean no-op.
6. **`release` `<version>` — hard-validate, then normalise.** `<version>` is **not** free text: it
   becomes a git branch name (`docs/release-<VERSION>`), page ids (`docs/release-notes/<VERSION>.md`,
   `docs/migration-guides/<VERSION>.md`), and the `## <VERSION>` changelog heading the upsert keys
   on. It is validated exactly as step 4 hard-validates `sync`'s story key **because** it forms a
   branch/ref — same discipline, different regex:

   ```text
   raw token must match:  ^[vV]?[0-9A-Za-z][0-9A-Za-z.]*(-[0-9A-Za-z.]+)*-?$
   normalise:             strip a single leading "v" or "V"  →  VERSION
   VERSION must additionally satisfy, or the run STOPs:
     - non-empty
     - contains no ".."
     - does not end in "." or "-"
     - does not end in ".lock"
   ```

   **The trailing `-?` is deliberate, not a stray permissiveness.** Without that trailing `-?`, a
   token ending in a bare `-` (e.g. `1.4-`) fails the regex **outright** — the `(-[0-9A-Za-z.]+)*`
   group requires at least one character after every `-`, so a trailing `-` has nothing to consume
   and the whole match fails — meaning it never reaches the "ends in '-'" check below and instead
   surfaces the generic "fails the token regex" message, which is **inaccurate** for this input
   (`1.4-` genuinely is only letters, digits, and `-`). Verified **against that superseded,
   `-?`-less regex**: `1.4-` was rejected outright, while `1.4.` and `1..4` passed it and reached
   their specific checks. The trailing `-?` lets a bare trailing dash pass the character-class check
   so it is caught by the **specific** "ends in '-'" STOP instead — the same fix shape as the
   `.lock` case below (widen the regex so the specific rule, not the generic one, catches it). It
   does not loosen anything else: `1--2` (an interior double-dash) still fails, because the repeated
   group still requires ≥1 character after each non-trailing `-`.

   Each failure is a **usage STOP** raised **before** any branch, dispatch, draft, or founder gate —
   a caller passing `release ../../oops` is rejected at the ladder, never after the founder has
   confirmed drafts. Each STOP states **its own** rejection reason (a single generic message would
   misdescribe `1.4.lock`, which _does_ satisfy "letters, digits, '.', '-'"):

   ```text
   fails the token regex   → invalid version "<raw>" — expected a token like 1.4.0 or v1.4.0
                             (letters, digits, ".", "-"; no path separators or whitespace)
   contains ".."           → invalid version "<raw>" — must not contain ".." (git refuses the
                             branch ref docs/release-<VERSION>)
   ends in "."              → invalid version "<raw>" — must not end in "." (git refuses the
                             branch ref docs/release-<VERSION> — verified:
                             `git check-ref-format --branch docs/release-1.4.` → invalid)
   ends in "-"              → invalid version "<raw>" — must not end in "-" (not a git ref-format
                             violation — `docs/release-1.4-` is a valid ref; the real reason is
                             token hygiene: "-" conventionally introduces a pre-release suffix, as
                             in 1.4.0-RC1, and a bare trailing "-" leaves that suffix empty)
   ends in ".lock"         → invalid version "<raw>" — must not end in ".lock" (git refuses the
                             branch ref docs/release-<VERSION>)
   empty after normalising → invalid version "<raw>" — version is empty after stripping the
                             leading "v" or "V"
   ```

   - **The `.` and `-` STOPs share one validation rule but have different true reasons — do not
     conflate them.** A trailing `.` genuinely is a git ref-format violation (verified above); a
     trailing `-` is not (also verified above) — its rejection is deliberate token hygiene, not a
     git constraint. Stating "git refuses" for both, as an earlier version of this text did, is
     false for the `-` half.
   - **The `.lock` rule is `VERSION.endswith(".lock")` — NOT a per-dot-component test.** Git's
     `.lock` prohibition applies to **slash**-separated ref components. The branch is
     `docs/release-<VERSION>`, whose last slash-component is `release-<VERSION>` — that component
     ends in `.lock` **iff `VERSION` does**. A per-**dot** component test would be **vacuous**:
     `1.4.lock` splits on `.` into `1`, `4`, `lock`, none of which _ends in_ `.lock` (they contain no
     dots), so such a rule rejects nothing and `1.4.lock` would reach `git checkout` and fail there —
     after the founder had confirmed drafts. Verified:
     `git check-ref-format --branch docs/release-1.4.lock` → `fatal: not a valid branch name`.
   - **Normalisation is identity-forming, not cosmetic.** `1.4.0`, `v1.4.0`, and `V1.4.0` all
     normalise to the **same** `VERSION` and therefore the same branch, PR, changelog section, and
     pages. The strip is **case-insensitive on this one leading character only** (`v` or `V`) —
     without it, `V1.4.0` would keep its `V` (the token regex's general `[0-9A-Za-z]` class accepts
     an uppercase `V` as an ordinary body character, same as any other alnum, so it is never rejected;
     only the strip step decides whether it is treated as the marker), forking a **second** branch
     (`docs/release-V1.4.0` alongside `docs/release-1.4.0`), a second open PR for the same version
     (the re-run dedupe keys on branch name, and these are two different names), a duplicate
     `## V1.4.0` changelog section, and duplicate release-notes/migration-guide pages — precisely the
     outcome this bullet exists to prevent.
   - **`VERSION` (normalised), not the raw token, is used everywhere downstream** — branch, PR title,
     commit string, page ids, changelog heading, no-op notices. The raw token is echoed **only** in
     the STOP messages above.
   - **Case is significant and deliberately not folded — but only past the single leading marker
     character.** The leading-`v`/`V` strip above is the **one** case-insensitive step; everything
     after it keeps its case exactly as typed. `1.4.0-RC1` and `1.4.0-rc1` are distinct `VERSION`s →
     distinct branches and page ids, which **collide** on a case-insensitive filesystem (macOS
     default). Folding the rest of the token would break legitimately case-distinct labels; v1
     accepts that collision while still closing the `V1.4.0`/`v1.4.0` split above — the two rules
     are not in tension: one governs the optional single-character prefix marker, the other governs
     the version body after it.
   - Beyond token safety, `<VERSION>` is **not** hard-validated against semver — a date-based label
     (e.g. `2026.07.1`) passes.

## `sync <STORY-KEY>` — shared pipeline split across the dispatch boundary

The procedure — the two-phase dispatch split, the deterministic regen algorithm, the voice/format
resolution chain, the `source:` refresh convention, and the no-op/change-gate semantics — is
defined once in `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md`; this command owns only the flow
around the founder-confirmation gate (a dispatched subagent cannot itself pause for it), the
argument validation above, and the gates below that decide whether `knowledge-engineer` is
dispatched at all.

1. **Manifest gate (AC5).** Shared with `release` — defined **once** in
   `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#manifest-gate-shared-by-sync-and-release` (the
   base-ref resolution pre-check that runs **before** the manifest read — an unresolvable
   `origin/<BASE-BRANCH>` is a STOP, never mistaken for "manifest absent" — then the
   checkout-independent `git show`, then the silent no-op on genuine absence). This command does not
   re-derive it; the gate's `git fetch origin --quiet` also covers step 2 below, so that step does
   not fetch again.

2. **Resolve the story branch (v1 diff source).** `sync` never depends on the currently-checked-out
   branch. The Manifest gate above already fetched `origin`, so this step does not fetch again:

   ```bash
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
   `STORY_BRANCH`, `origin/<BASE-BRANCH>` (the **remote-tracking** base ref from project-context,
   not the bare local branch name — a stale local checkout must never skew the diff), and the story
   key. Per `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md` §2/§3, phase 1 computes `CHANGED_FILES` +
   `CHANGED_DIFF` from `origin/<BASE-BRANCH>...$STORY_BRANCH`, resolves affected rows, produces the
   deterministic regen content for the `auto` rows + `llms.txt`, drafts narrative how-to refreshes
   via `writing-docs`, and returns all of it to this command layer.

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

## `release <version>` — shared pipeline split across the dispatch boundary

The release run mirrors `sync`'s two-phase dispatch and command-layer founder-confirm gate. The
shared skeleton lives in `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md` §2, and the release-specific
procedure — enumeration, aggregation, upsert, ADR-link resolution, branch/PR control flow, no-op
semantics — is defined once in that ref's **§§10–14**. This command owns only the gates below, the
argument validation above, and the founder-confirm gate between the two dispatches.

1. **Manifest gate (AC6).** Shared with `sync` — same pointer, same mechanics: see step 1 of the
   `sync` procedure above,
   `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#manifest-gate-shared-by-sync-and-release`. The
   base-ref resolution pre-check runs first (an unresolvable `origin/<BASE-BRANCH>` STOPs — it is
   never mistaken for "manifest absent"), then the checkout-independent `git show`, then the silent
   no-op on genuine absence. Do not dispatch `knowledge-engineer` on either exit path.

2. **Enabled-row gate — resolve `ENABLED_ROWS` once, then thread it everywhere.** From the manifest,
   resolve which of the three `release`-triggered registry rows (`changelog`, `release-notes`,
   `migration-guide`) are **enabled**; call that subset `ENABLED_ROWS`.
   - **Absent is never default-on.** A row **present** in the manifest row-table is enabled per its
     `enabled` column (the template's Fill rules default it to `true` for every _written_ row). A row
     **absent** from the table is **not** enabled. Absence has two causes and the distinction does not
     matter here: the type was offered and declined (a `<!-- declined: <type> -->` comment), or the
     row was deleted (which a future re-init may re-offer — `/init`'s business, not `release`'s).
     **Never infer a missing row as enabled.**
   - **`ENABLED_ROWS` empty** → **clean no-op**: print
     `no release-triggered doc types enabled in docs-manifest.md — nothing to generate` and exit
     without a PR. Informational, not silent — the manifest exists, so the founder opted in.
   - **`ENABLED_ROWS` is a per-row filter, not a one-time collective gate.** It is an explicit input
     to phase 1, to the gate, and to phase 2, and each **must re-consult it per row**: phase 1 drafts
     **only** enabled rows' artifacts, the gate presents **only** those drafts, phase 2 writes
     **only** those pages. This is the release instance of the §2 step 4 / §3 invariant that
     regeneration "never touches an unaffected row's pages". A founder who disables `release-notes` or
     `migration-guide` must never have those pages drafted, shown, or created. `ENABLED_ROWS =
{changelog}` produces exactly one artifact, one gate item, one written page.

3. **Resolve the last tag and the merged-story set.** Per `refs/docs-pipeline.md` §10 — the base-ref
   pre-check, the **positive shallow-clone pre-check**, the `No names found`-only fallthrough, the
   **single-ended** no-tags range, the RS/US delimited `git log` format and its parse rules, and the
   story-key regex scoped to the `PROJECT_KEYS` set (primary key + manifest-configured additional
   keys). Every git failure is a **STOP**, never a silent fallthrough. **No stories merged** → clean
   no-op with §14's two notice wordings (never an empty interpolation).

4. **Dispatch `knowledge-engineer` Phase 1 (compute & draft, writes nothing).** Pass it `VERSION`,
   `ENABLED_ROWS`, the resolved commit range, the merged-story key set (each key with its
   `(subject, body)` records), and `origin/<BASE-BRANCH>`. Phase 1 drafts **only the artifacts whose
   row is in `ENABLED_ROWS`** — the changelog entry (§11), the ADR-linked release notes (§12), and/or
   the headings-only migration stub (§12) — and returns the drafts **it actually produced** (plus the
   resolved merged-story set and ADR-link map), each **labelled with its row** so the gate and phase 2
   filter on the same subset. **Nothing is written to disk in phase 1.**

5. **Founder-confirmation gate (command layer, between the two dispatches).** Present **every
   release-artifact draft phase 1 returned — and only those** (the `ENABLED_ROWS` subset, never a
   fixed set of three) and wait for explicit founder confirmation. The founder may accept, edit, or
   reject each. An enabled changelog draft rides the **same** gate because its registry
   `generation-mode` is `draft-for-review` — the registry marks all three `draft-for-review`, and
   nothing is written un-confirmed. If `ENABLED_ROWS` resolved to a single row, the gate presents a
   single draft. **This gate is the only place release content is edited** (§13's "Where edits live").
   `gh` MAY enrich what is **displayed** here (e.g. PR titles alongside keys); it MUST NOT feed any
   byte written to a file (§11's `gh` boundary).

6. **Dispatch `knowledge-engineer` Phase 2 (write confirmed, fresh dispatch).** Hand it `VERSION`,
   `ENABLED_ROWS`, and the founder-confirmed drafts **verbatim** (inline or via
   `${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh` temp files by path) — never re-derived. Phase 2 checks
   out the release branch per §13 (fresh from `origin/<BASE-BRANCH>` head on a first run; the
   **existing** branch **at its remote head** on a re-run, after §13's precondition + both guards
   pass), writes the confirmed content **for `ENABLED_ROWS` only** under their manifest-resolved
   `target-path`s, applies §11's changelog upsert, deterministically regenerates the doc index +
   `llms.txt` (§14), and — **only if `git status --porcelain` on the written paths is non-empty** —
   commits via `conventional-commit` with the `Release-Generated: <VERSION>` trailer, pushes, and
   opens or updates the release PR.

## Release branch/PR naming

- Branch `docs/release-<VERSION>`; PR title `docs(docs): release <VERSION>`. Cut from the **base
  branch head** (`origin/<BASE-BRANCH>`), **not** a story branch — release aggregates work already
  merged to base.

Full contract (cut point, commit string + trailer, PR base, local-branch precondition, both re-run
guards — including the prohibition on `reset --hard` / force-push, a deliberate divergence from §7
— and the control-flow tail) is defined once in
`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#13-release-mode--branch--pr--control-flow` — this
command does not re-derive it.

## Founder-confirm-gate authority note

Auto (deterministic) rows are written **un-gated** — they are computed in phase 1 and written in
phase 2 without a confirmation step, because they are fully derived and idempotent. Narrative
(how-to) drafts are written **only after explicit founder confirmation** at this command layer. A
dispatched subagent never runs the gate itself (it cannot pause for interactive input) — this
command owns it, exactly as `commands/adr.md` does for the ADR pipeline.

## Branch/PR naming

- Branch `docs/sync-<STORY-KEY>`; PR title `docs(docs): sync <STORY-KEY>`. Both cut from the
  **story branch head**, not `<BASE-BRANCH>` — the deterministic regen must read the story
  branch's changed source.

Full contract (cut-point detail, commit string, PR base, re-run open-or-update behaviour, diff
source) is defined once in
`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#7-branch--pr-naming--control-flow` — this command does
not re-derive it.

## `llms.txt` format (v1 decision)

Index-only, grouped by Diátaxis quadrant, content matching the `llms-txt` row's `source-of-truth`
cell in `refs/doc-types.md` — see that cell rather than this restating it. Regenerated every run
(AC4), committed only if changed (AC6). Full format decision:
`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#8-llmstxt-format-v1-decision`.

## Command control flow

After the phase-2 PR is raised, drive the review loop to convergence exactly as `/sdlc:adr` does:

```bash
/loop /sdlc:loop <PR_URL>
```

If the harness cannot nest `/loop` from inside a command, fall back to `ScheduleWakeup` to drive
`sdlc:loop`'s pass-cycle instead (same effect — the loop is the last thing the session does), then
let its final pass release. If the command hit a terminal STOP, WARNING, or no-op before a PR was
raised, release the session directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — see
`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#7-branch--pr-naming--control-flow` for exactly which
pre-PR exit paths this covers.

## Error handling

| Scenario                                                                                                        | Behaviour                                                                                                                                                                                                                                             |
| --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.claude/project/docs-manifest.md` absent                                                                       | **Silent** no-op — no branch, no dispatch, no PR, no error, **no stdout** (AC5). Distinct from a usage STOP, which prints.                                                                                                                            |
| Empty `$ARGUMENTS` / unrecognised first token                                                                   | Usage STOP (prints the usage message).                                                                                                                                                                                                                |
| `sync` with missing/malformed story key (fails `^[A-Z][A-Z0-9]*-[0-9]+$`)                                       | Usage STOP (prints the usage message).                                                                                                                                                                                                                |
| Recognised future-mode token (`seed`/`audit`/`distill`)                                                         | Print "mode not yet implemented (see Epic NA-50)" and exit cleanly — not an error.                                                                                                                                                                    |
| `sync` but no `origin/feat/<STORY-KEY>` or `origin/fix/<STORY-KEY>` (post-merge / never-branched)               | Emit the explicit WARNING (v1 is branch-diff-only; post-merge deferred to NA-55); exit **without** a silent success.                                                                                                                                  |
| `refs/doc-types.md` unreadable/malformed                                                                        | Surface the failure and STOP — never regenerate from a partial registry.                                                                                                                                                                              |
| Manifest present but no enabled `sync`-triggered row affected, and `llms.txt` unchanged                         | Clean no-op — no commit, no PR (AC6).                                                                                                                                                                                                                 |
| Deterministic regen produced byte-identical output and no narrative draft confirmed                             | No commit, no PR (AC6) — write phase detected an empty `git status --porcelain`.                                                                                                                                                                      |
| Founder rejects all narrative drafts but deterministic content changed                                          | Still commit + PR the deterministic regen (AC6 — content changed).                                                                                                                                                                                    |
| Story branch diff yields no changed files                                                                       | Only `llms.txt` is (re)generated; commit/PR only if it changed.                                                                                                                                                                                       |
| `gh` / `raise-pr.sh` failure                                                                                    | STOP and surface — the write is on a branch and reviewable; never leave a raised-but-broken state silently.                                                                                                                                           |
| `release` with missing/empty `<version>`                                                                        | Usage STOP (prints the usage message).                                                                                                                                                                                                                |
| `release` with a `<version>` failing the token regex, or containing `..` / a path separator (e.g. `../../oops`) | Usage STOP stating **that** reason, raised **at the validation ladder** — before any branch, dispatch, draft, or founder gate.                                                                                                                        |
| `release` with a `<version>` ending `.lock` (e.g. `1.4.lock`)                                                   | Usage STOP stating the `.lock` reason specifically — `VERSION.endswith(".lock")` is the test; git rejects the ref `docs/release-1.4.lock`, so it is caught up-front rather than at `git checkout` after the gate.                                     |
| Manifest present but no `release`-triggered row enabled                                                         | Clean no-op — print `no release-triggered doc types enabled…`, no PR.                                                                                                                                                                                 |
| Manifest row absent for a release type (declined at `/init`, or deleted)                                        | Treated as **not enabled** — never inferred as default-on. Excluded from `ENABLED_ROWS`.                                                                                                                                                              |
| Manifest enables only **some** release rows                                                                     | Not an error — only those rows are drafted, gated, and written. Disabled rows' pages are never created or touched.                                                                                                                                    |
| No stories merged in the range, `LAST_TAG` set                                                                  | Clean no-op — `no stories merged since <LAST_TAG> — nothing to release`, no PR.                                                                                                                                                                       |
| No stories merged in the range, no tags exist                                                                   | Clean no-op — `no stories merged since the start of history — nothing to release` (never an empty interpolation).                                                                                                                                     |
| Repo has no tags yet (full clone)                                                                               | Not an error — range is the **single-ended** `origin/<BASE-BRANCH>` (full history, root inclusive).                                                                                                                                                   |
| **Shallow clone**                                                                                               | Surface and STOP (`run: git fetch --unshallow`) — caught by the **positive** `git rev-parse --is-shallow-repository` pre-check, because a shallow clone with unreachable tags emits the _identical_ `No names found` text as a genuine first release. |
| `git fetch` fails, or `origin/<BASE-BRANCH>` will not resolve                                                   | Surface and STOP — resolved **before the manifest gate** (never mistaken for "manifest absent") and again **before** `git describe` (never mistaken for "no tags yet").                                                                               |
| Manifest present but the `llms-txt` row is disabled or absent                                                   | Not an error — `llms.txt` is a `sync`-triggered row, not part of `ENABLED_ROWS`; `release` independently checks its enabled state and does not write or touch it this run if disabled/absent. Any existing `llms.txt` is left as-is.                  |
| `git describe --tags` fails with anything other than `No names found`                                           | Surface and STOP. `No names found` is the **only** fallthrough text, trusted only because the shallow pre-check already ran. `No tags can describe` is deliberately **not** matched.                                                                  |
| `git log` failure                                                                                               | Surface and STOP — never silently release an empty or partial range.                                                                                                                                                                                  |
| A commit body mentions `BREAKING CHANGE:` in prose rather than as a footer                                      | **Not** breaking — the test is line-anchored (`^BREAKING[ -]CHANGE:`), never a substring search.                                                                                                                                                      |
| `gh` unavailable / rate-limited                                                                                 | Never affects written content — `gh` is display-only enrichment at the confirm gate. Output is byte-identical whether `gh` answers or not.                                                                                                            |
| A merged story has no motivating ADR                                                                            | Its release note omits the ADR link — never fabricated.                                                                                                                                                                                               |
| Repo has no `docs/adr/` directory                                                                               | Every release note is ADR-less; not an error.                                                                                                                                                                                                         |
| A **local** `docs/release-<VERSION>` holds commits not reachable from its remote                                | **STOP** (local-branch precondition) — never discard unpushed work, and never clobber it on the first-run path either.                                                                                                                                |
| Re-run: branch exists on `origin`, all page-touching commits carry the trailer                                  | Not an error — check out at the remote head, write on top, commit + fast-forward push only if content changed. Never reset, never force-push.                                                                                                         |
| Re-run: branch carries **out-of-pipeline** edits to generated pages (no `Release-Generated:` trailer)           | **STOP** (re-run content guard) — surface the paths and the PR number.                                                                                                                                                                                |
| Re-run: a prior run's **founder gate edit** is present on a generated page                                      | **Re-derived**, not preserved and not STOPped — phase 1 re-drafts and the gate re-presents.                                                                                                                                                           |
| Re-run: `## <VERSION>` already present in the cumulative changelog                                              | Not an error — the section is **replaced in place** (upsert), never prepended a second time.                                                                                                                                                          |
| Founder rejects every enabled draft and deterministic regen is byte-identical                                   | No commit, no PR — write phase detected an empty `git status --porcelain`.                                                                                                                                                                            |

Mode + args:
$ARGUMENTS
