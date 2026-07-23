---
description: Generate and maintain this repo's public docs surface via the doc-type registry and per-repo docs manifest. Ships five live modes — `sync` diff-drives deterministic reference-doc + `llms.txt` regen and drafts gated how-to refreshes; `release <version>` aggregates merged stories since the last tag into changelog/release-notes/migration-guide; `seed <type> [topic]` scaffolds one new narrative page for founder authoring at the confirm gate (`seed adr "<pattern>"` routes to the ADR pipeline instead); `audit [--dry-run]` scans activated rows for drift, auto-corrects via PR, flags narrative drift; `distill ["<focus>"]` mines the learnings corpus for promotable ADR candidates via refs/adr-pipeline.md. All modes regenerate the doc index + `llms.txt` where applicable, run behind the knowledge-engineer agent, with the founder-confirmation gate at this command layer.
---

## Modes (dispatched from `$ARGUMENTS`)

| Invocation                       | Mode        | v1 status           |
| -------------------------------- | ----------- | ------------------- |
| `/sdlc:docs sync <STORY-KEY>`    | **sync**    | Shipped (NA-52)     |
| `/sdlc:docs release <version>`   | **release** | Shipped (NA-53)     |
| `/sdlc:docs seed <type> [topic]` | **seed**    | **Shipped (NA-54)** |
| `/sdlc:docs audit [--dry-run]`   | **audit**   | **Shipped (NA-55)** |
| `/sdlc:docs distill ["<focus>"]` | **distill** | **Shipped (NA-57)** |

## Argument validation

Parse `$ARGUMENTS` into `<mode>` (the first token) and the mode's remaining args. Apply, in order:

1. **Empty `$ARGUMENTS`** → STOP with the usage message:
   `usage: /sdlc:docs sync <STORY-KEY> | release <version> | seed <type> [topic] | seed adr "<pattern>" | audit [--dry-run] | distill ["<focus>"]`.
2. **Unrecognised first token** (not one of `sync`/`release`/`seed`/`audit`/`distill`) → STOP with
   the same usage message.
3. **`sync` with a missing or malformed story key** — the story key must match
   `^[A-Z][A-Z0-9]*-[0-9]+$` (e.g. `NA-52`). If the key is absent or fails the regex → STOP with the
   usage message. This is a **usage STOP** (a caller error), distinct from the manifest-absent
   silent no-op below.
4. **`release` with a missing or empty `<version>`** → STOP with the usage message. A **usage STOP**,
   distinct from the manifest-absent silent no-op and the no-stories-merged clean no-op.
5. **`release` `<version>` — hard-validate, then normalise.** `<version>` is **not** free text: it
   becomes a git branch name (`docs/release-<VERSION>`), page ids (`docs/release-notes/<VERSION>.md`,
   `docs/migration-guides/<VERSION>.md`), and the `## <VERSION>` changelog heading the upsert keys
   on. It is validated exactly as step 3 hard-validates `sync`'s story key **because** it forms a
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

6. **`seed` with a missing `<type>`** → STOP with the usage message **plus** the valid type list. A
   **usage STOP** (caller error), distinct from the manifest-absent silent no-op below.
7. **`seed` `<type>` = `adr`** — the **special ADR route** (branches before the generic seed gates;
   `adr` never enters `SEED_TYPES`). **Empty-pattern STOP (relocated command-layer guard):** if the
   pattern text after `adr` is empty (`/sdlc:docs seed adr` or `/sdlc:docs seed adr ""`) → **STOP**
   with a usage message (`usage: /sdlc:docs seed adr "<pattern>"`), **before** dispatching Phase 1 —
   never draft an ADR from empty input. This guards `seed adr`'s pattern only. Otherwise dispatch
   the **ADR pipeline (seed)** at `${CLAUDE_PLUGIN_ROOT}/refs/adr-pipeline.md` with an explicit
   **ADR dispatch-type signal** (there is no longer a command name to infer it from): **no**
   manifest gate, **no** type-activation gate — the `docs/adr/` target resolves from
   `project-context.md` exactly as the retained pipeline does. The two-phase split, the
   founder-confirm gate at this command layer, and the `docs(adr):` branch/PR naming are handed to
   the agent per `refs/adr-pipeline.md`'s §3a command-layer-flow section, not restated here.
8. **`seed` `<type>` not in `SEED_TYPES` ∪ `{adr}`** → usage STOP naming what was passed and
   enumerating the valid set:

   ```text
   unknown seed type "<type>" — valid types: <comma-separated resolved SEED_TYPES>
   (derived from the seed-triggered rows of refs/doc-types.md)
   for ADRs, use seed adr "<pattern>" instead
   ```

   `SEED_TYPES` is resolved **at read time** from `refs/doc-types.md`'s `trigger` cells, minus `adr`
   — see `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md` §15. The enumerated list in this message is
   **rendered from the resolved `SEED_TYPES`**, never typed as a literal — otherwise it becomes the
   hardcoded copy the derivation rule exists to avoid. **This file is `command-reference`
   source-of-truth** (`refs/doc-types.md`'s `command-reference` row) — the generated reference page
   now derives only from this file's frontmatter plus a link back here (`refs/docs-pipeline.md` §3
   steps 1–2, never a body copy), so a stale literal here would no longer leak into that published
   page, but it would still mislead every reader who follows the Source link to see this file's real
   runtime behavior, and it would still be logic that silently drifts from the registry. The
   placeholder above stays deliberate, not merely illustrative, for that reason. As of this writing
   that placeholder resolves to `concept, tutorial, integration-guide, how-to` (shown for the
   reader's convenience only; never copy this list back into the template above).

9. **`seed` `<topic>`, when supplied, is validated and normalised here — at the ladder, before any
   gate.** The slugify rule and its **three** reachable STOPs (empty / >80 chars / reserved page id)
   are defined once in `refs/docs-pipeline.md` §15 and are **not** restated here. This placement is
   the direct lesson from NA-53, where a version token that forms a branch name reached the gate
   unvalidated. **`<topic>` omitted is NOT an error** (the signature is `[topic]`) — the command
   prompts for it, but **after** the manifest and type-activation gates, so a repo with nothing to
   do is never prompted first. **A prompted topic runs the identical ladder** (§15): validation the
   primary input path never reaches is not validation.
10. **`audit` flag recognition — the entire `audit` validation surface.** `audit` takes no free-text
    argument (nothing forming a branch, path, or ref), so NA-53's `<version>` ladder and NA-54's
    `<topic>` slug ladder have **no analogue here** — do not import one.
    1. **`audit` with no further tokens** → default (PR) mode. Not an error.
    2. **`audit --dry-run`** (the flag is the sole remaining token) → dry-run (report-only) mode.
    3. **`audit <anything-else>`** — any remaining token not exactly `--dry-run` (e.g. `--dryrun`,
       `foo`, `--dry-run extra`) → **usage STOP**:

       ```text
       unknown argument for audit — usage: /sdlc:docs audit [--dry-run]
       ```

       A usage STOP (caller error), **distinct from the manifest-absent silent no-op** — a founder
       who fat-fingers `--dryrun` must not get a live PR-opening run they thought was a dry run.

## `sync <STORY-KEY>` — shared pipeline split across the dispatch boundary

The procedure — the two-phase dispatch split, the deterministic regen algorithm, the voice/format
resolution chain, the `source:` refresh convention, and the no-op/change-gate semantics — is
defined once in `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md`; this command owns only the flow
around the founder-confirmation gate (a dispatched subagent cannot itself pause for it), the
argument validation above, and the gates below that decide whether `knowledge-engineer` is
dispatched at all.

1. **Manifest gate (AC5).** Shared with `release` — defined **once** in
   `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#manifest-gate-shared-by-sync-release-seed-and-audit` (the
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

   - **Neither `origin/feat/<STORY-KEY>` nor `origin/fix/<STORY-KEY>` exists** → select the
     **merged-commit** diff source per
     `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#26-dual-diff-source--selection-rule`: locate the
     commit(s) on `origin/<BASE-BRANCH>` carrying `<STORY-KEY>` (the `PROJECT_KEYS`-scoped regex from
     §10 — never the loose matcher) and set `CHANGED_FILES` / `CHANGED_DIFF` from the merged range
     (`<sha>^..<sha>`, or the union across matches). **Zero commits carry the key** → STOP with
     `cannot locate a merged commit for <STORY-KEY> on origin/<BASE-BRANCH> — nothing to diff`
     (never a silent no-op). `git fetch` failure / unresolvable `origin/<BASE-BRANCH>` → STOP.
     `STORY_BRANCH` stays empty; set `REGEN_TREE_REF=origin/<BASE-BRANCH>`
     (`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#2-two-phase-dispatch-split-across-the-confirmation-boundary`
     step 2 — base HEAD already contains the landed commit(s), so it is the tree the regen reads
     from and the tree Phase 2 checks out from).

3. **Dispatch `knowledge-engineer` Phase 1 (compute & draft, writes nothing).**
   - **`STORY_BRANCH` resolved** (the common case) → pass `STORY_BRANCH`, `origin/<BASE-BRANCH>`
     (the **remote-tracking** base ref from project-context, not the bare local branch name — a
     stale local checkout must never skew the diff), and the story key. Per
     `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md` §2 step 3, phase 1 **computes**
     `CHANGED_FILES`/`CHANGED_DIFF` from `origin/<BASE-BRANCH>...$STORY_BRANCH` itself;
     `REGEN_TREE_REF=$STORY_BRANCH` (§2 step 2).
   - **`STORY_BRANCH` empty — merged-commit path selected** (previous step) → pass the
     **precomputed** `CHANGED_FILES`/`CHANGED_DIFF` (already derived from the merged range above)
     and `REGEN_TREE_REF=origin/<BASE-BRANCH>` instead. Per
     `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md` §2 step 3, phase 1 uses these **verbatim** — it
     does **not** recompute from `$STORY_BRANCH` (there is none to diff against). This is the fix
     that makes the merged-commit path actually regenerate — a bare `STORY_BRANCH`-only dispatch
     here would diff against nothing and silently no-op.
   - In both shapes, phase 1 resolves affected rows, produces the deterministic regen content for
     the `auto` rows + `llms.txt` (reading source content from `REGEN_TREE_REF`, §2 step 5), drafts
     narrative how-to refreshes via `writing-docs`, and returns all of it to this command layer.

4. **Founder-confirmation gate (command layer, in-session, between the two dispatches):**
   - Present the deterministic regen summary (informational — auto rows are not gated; they were
     already computed, not yet written) and each narrative how-to draft (gated). Wait for explicit
     founder confirmation on the narrative drafts — identical discipline to `/sdlc:analyze`'s apply
     gate and the `seed adr`/`distill` routes' founder-confirmation gate below: no inline auto-apply
     path.
   - The founder may accept, edit, or reject each narrative draft.
   - **The gate is skipped when there are zero narrative drafts** — proceed straight to phase 2
     with the deterministic content only.

5. **Dispatch `knowledge-engineer` Phase 2 (write confirmed, fresh dispatch).** Hand it the
   deterministic content **and** the founder-confirmed narrative drafts **verbatim** (inline or via
   session temp-dir files referenced by path, per `${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh`) —
   never re-derived. Phase 2 checks out the branch (see Branch/PR naming below, cut from
   `REGEN_TREE_REF` — the story branch head when present, or `origin/<BASE-BRANCH>` on the
   merged-commit path; never a bare local `<BASE-BRANCH>`), writes the deterministic regen +
   `llms.txt` + confirmed narrative drafts under their manifest-resolved `target-path`s, then —
   **only if content changed** (`git status --porcelain` on the written target paths is non-empty,
   AC6) — commits via `conventional-commit`, pushes, and opens or updates the sync PR.

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
   `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#manifest-gate-shared-by-sync-release-seed-and-audit`. The
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

   **Compute the out-of-scope key warning (AC3) — only when `PROJECT_KEYS ≠ ∅`.** Over the same
   `(subject, body)` records §10 enumerated (no second scan), compute `OUT_OF_SCOPE` and its
   `LIKELY_KEYS` / `STANDARDS_MATCHES` partition per
   `refs/docs-pipeline.md` §10's `### Out-of-scope key warning`. When `PROJECT_KEYS = ∅` (State A),
   **skip this entirely** — nothing is out-of-scope; never route `∅` into a suppressing no-op. **The
   warning fires iff `LIKELY_KEYS ≠ ∅` — never merely `OUT_OF_SCOPE ≠ ∅`.** `OUT_OF_SCOPE` also
   contains `STANDARDS_MATCHES`, and a range whose only out-of-scope tokens are standards-prefixed
   (e.g. bodies citing `RFC-2119`/`SHA-256`, zero genuine unrecognised keys) has `LIKELY_KEYS = ∅`
   even though `OUT_OF_SCOPE ≠ ∅` — that range must **not** fire the warning (it would render an
   empty individual-key list under an active header and a "register this as a project" footer,
   driven by demoted standards noise alone — the exact inversion AC4 exists to prevent). The warning
   is **advisory** (never blocks) and prints at whichever exit the run reaches:
   - **No-op split (§14).** If the emitted (`IN_SCOPE`) set is empty:
     - `PROJECT_KEYS = ∅`, **or** `LIKELY_KEYS = ∅` (including the standards-only case, whether or
       not `STANDARDS_MATCHES ≠ ∅`) → the existing clean no-op (§14's two `LAST_TAG` wordings). No
       warning.
     - `PROJECT_KEYS ≠ ∅` **and** `LIKELY_KEYS ≠ ∅` → **the warning no-op** (the pure silent-drop
       case — at least one genuine unrecognised key): print the warning below, then exit 0 with
       **no PR**. The message must **not** claim unqualified "nothing to release". These two
       branches are keyed on the single variable `LIKELY_KEYS` (empty vs. non-empty), so they are
       **mutually exclusive** — no range matches both, and no legacy-key range can be silently
       swallowed by the clean branch.
   - **Gate path.** If the emitted set is non-empty and `LIKELY_KEYS ≠ ∅`, carry `OUT_OF_SCOPE` (and
     its `LIKELY_KEYS`/`STANDARDS_MATCHES` partition) to the founder-confirm gate (step 5). If
     `LIKELY_KEYS = ∅` (including the standards-only case), the gate proceeds normally with **no**
     warning line, even if `STANDARDS_MATCHES ≠ ∅`.

The warning text is built from **live state**, never hardcoded. **The entire block below — header,
count, colon, individual list, standards-demotion line, and remediation footer — renders as one
unit, gated on `LIKELY_KEYS ≠ ∅`; none of these pieces ever appears alone:**

```text
WARNING: <N> Jira-key-shaped token(s) in this range are outside PROJECT_KEYS, so they are dropped
from this release and will NOT appear in <human-named ENABLED_ROWS>:
  - <LIKELY_KEY> — <its most-recent subject>
  … (one line per LIKELY_KEYS token)
(<M> token(s) matched common-standards prefixes (<distinct folded prefixes, e.g. RFC, SHA>) and were not listed individually — if any names a real Jira project, add its prefix as above.)
To include them, <section-aware remediation>, then re-run `release <version>`.
```

- **`N = |OUT_OF_SCOPE| = |LIKELY_KEYS| + |STANDARDS_MATCHES|`** (the total dropped-token count named
  in the header) and **`M = |STANDARDS_MATCHES|`** (the demoted-only count in the parenthetical) are
  **distinct variables — never the same letter, never interchanged.** The individual list under the
  header shows one line per `LIKELY_KEYS` token only; `STANDARDS_MATCHES` tokens never get their own
  line, only the aggregated `M`-count line.
- **Name the actually-enabled release rows, not "the changelog".** Map `changelog → "the changelog"`,
  `release-notes → "the release notes"`, `migration-guide → "the migration guide"`, listing **only**
  those in `ENABLED_ROWS` this run. (`ENABLED_ROWS` is resolved at step 2, so it is known on both the
  no-op path and the gate path.)
- **The `STANDARDS_MATCHES` line is emitted only when `STANDARDS_MATCHES ≠ ∅`, and only as an
  addendum inside an already-firing warning** (`LIKELY_KEYS ≠ ∅`) — it is never, by itself, what
  fires the warning (see the `LIKELY_KEYS ≠ ∅` trigger above). Its parenthesised prefix list is the
  **distinct prefixes actually folded this run** — never fixed text, never a bare count.
- **Section-aware remediation** — check whether `.claude/project/docs-manifest.md` already contains an
  `## Additional Jira project keys` heading:
  - **present** → "add the prefix(es) to the existing `## Additional Jira project keys` section".
  - **absent** (an upgraded repo that never re-ran init) → "add an `## Additional Jira project keys`
    section (a comma-separated key list — see `refs/docs-manifest-template.md`)". Never tell a founder
    to edit a section that isn't there.

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

   If step 3 carried a non-empty `LIKELY_KEYS` to this gate (`PROJECT_KEYS ≠ ∅`, the emitted set was
   non-empty, and at least one genuine unrecognised key exists — never merely `STANDARDS_MATCHES ≠
∅`), print the step-3 out-of-scope key warning **alongside the drafts, before the founder
   confirms** — same text, same `ENABLED_ROWS`-named rows and section-aware remediation. It is
   **advisory only: it never blocks** the release and never mutates the manifest.

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

## `seed <type> [topic]` — shared pipeline split across the dispatch boundary

The seed run mirrors `sync`/`release`'s two-phase dispatch and command-layer founder-confirm gate.
The shared skeleton lives in `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md` §2, and the seed-specific
procedure — type resolution, the topic/slug ladder, `PAGE` construction, the gate ladder, page
artifacts, branch/PR control flow, no-op and re-run semantics — is defined once in that ref's
**§§15–19**. This command owns only the gates below, the argument validation above, and the
founder-confirm gate between the two dispatches.

**The ordering below is load-bearing.** Everything through step 5 runs **before the founder authors
anything**: for `seed`, a post-gate STOP does not merely waste a machine's work as it would in
`sync` or `release` — **it destroys the founder's entire page**. Every rejection whose inputs are
already available is hoisted ahead of the gate.

1. **Argument validation** — the ladder above, including a supplied `<topic>`.

2. **Manifest gate (AC5).** Shared with `sync` and `release` — defined once at
   `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#manifest-gate-shared-by-sync-release-seed-and-audit`
   (base-ref resolution pre-check → checkout-independent `git show` → silent no-op on genuine
   absence). **Not re-derived here**; `seed` is its third consumer. If **absent** → **silent no-op**:
   no prompt, no branch, no dispatch, no PR, no error, **no stdout**, exit 0. Do not dispatch
   `knowledge-engineer`.

3. **Type-activation gate (AC2)** — per `refs/docs-pipeline.md` §16 step 3. Resolve `SEED_ROW` from
   the manifest; the type is activated iff its row is **present** **and** `enabled = true`.
   **Absent is never activated — never infer a missing row as enabled.** Not activated → print
   `doc type "<type>" is not activated in .claude/project/docs-manifest.md — nothing seeded`
   plus `(add or enable its row to seed this type)`, and make **no write**. **Informational, not
   silent** — the manifest exists, so the founder opted in. Do not dispatch `knowledge-engineer`.
   **`target-path` comes from `SEED_ROW`, not the registry default.**

4. **Topic resolution (prompt if omitted).** Prompt here — this is the only layer that can pause for
   input — and run the **identical** §15 ladder on the answer. Placed **after** gates 2–3 so a repo
   with no manifest is never prompted before its silent no-op.

5. **Page-exists + branch-state gate — all of it pre-gate** (`refs/docs-pipeline.md` §16 step 5).
   Construct `PAGE` by **normalising the trailing slash before joining** — every registry
   `target-path` ends in `/`, so a naive join makes this gate **fail open** and phase 2 overwrite a
   published page (§16 carries the verified rationale). Check it checkout-independently at
   `origin/<BASE-BRANCH>`. Exists at base → **STOP** (`seed` is a create verb). Exists only on the
   branch → a re-run: **§18's local-branch precondition and both re-run guards are evaluated HERE**,
   before phase 1 dispatches. Exists nowhere → first run — **the local-branch precondition still
   runs.**

6. **Dispatch `knowledge-engineer` Phase 1 (scaffold & draft, writes nothing).** Pass it `<type>`,
   `SEED_ROW` (its `target-path`), `SLUG`, the **raw** topic text, the normalised `PAGE`, and
   `origin/<BASE-BRANCH>`. Phase 1 loads `writing-docs` unconditionally, scaffolds exactly one page
   from the `<type>`'s registry-quadrant template, never invents facts to fill a section, emits the
   required frontmatter, and returns the scaffold. **Nothing is written to disk in phase 1.**

7. **Founder-confirm gate (AC3) — this is where the founder authors.** Present the scaffold; the
   founder may accept, edit, author over, or reject it. **This is the mode's whole point:** unlike
   `sync`/`release`, where the gate mostly confirms machine-derived content, here the gate **is the
   authoring surface**, and heavy editing is the expected path.
   - **Validate the confirmed content HERE, at the gate, while it still exists** — specifically the
     required `title` + `description` frontmatter (`refs/docs-pipeline.md` §17). **Not deferred to
     phase 2**: phase 2 is a fresh dispatch holding an opaque payload, so a check there can only STOP
     — it cannot ask the founder to fix the missing line — converting a one-line correction into the
     loss of a whole authored page.
   - For a `how-to` / `integration-guide`, present the `source:` glob list: globs supplied → written
     with `source:` (future `sync` runs draft refreshes); omitted → **the key is omitted entirely**,
     never written empty, and **never inferred** (§17).
   - **Founder rejects / does not confirm** → write nothing, no branch, no PR, no phase-2 dispatch;
     report and exit cleanly. Unlike `release`, there is no deterministic half worth committing.
   - `gh` and the learnings corpus MAY enrich what is **displayed** here; neither may feed a written
     byte except through the founder's confirmation (§19).

8. **Dispatch `knowledge-engineer` Phase 2 (write confirmed, fresh dispatch).** Pass it `<type>`,
   `SEED_ROW`, `SLUG`, the normalised `PAGE`, and the founder-confirmed content **verbatim** (inline
   or via `scripts/tmp-dir.sh` temp files by path — **never re-derived**). Phase 2 re-verifies the
   precondition + guards as a **mandatory** TOCTOU backstop (preserving the confirmed content on a
   STOP), writes the confirmed content to `PAGE` and **only** to `PAGE`, regenerates the index +
   `llms.txt` per §19 (**`llms.txt` only if its own manifest row is present and enabled — checked
   independently of `SEED_ROW`**), and commits/pushes/opens-or-updates the PR **only if
   `git status --porcelain` on the written paths is non-empty** (AC4).

## `audit [--dry-run]` — single-dispatch drift scan + deterministic correction

Unlike `sync`/`release`/`seed`, `audit` has **no founder-confirm gate** and therefore **no two-phase
dispatch split** — its `auto`-row corrections are un-gated and its narrative findings are flags, not
writes. It collapses to a **single** `knowledge-engineer` dispatch. The full procedure is defined
once in `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md` **§§20–24**; this command owns only the
manifest gate, the flag ladder above, the single dispatch, and the report/PR surfacing.

```text
1. argument validation  →  2. manifest gate (§1)  →  3. dispatch knowledge-engineer (audit)
→  4. scan + compute (§§20–22)  →  5a. --dry-run: report, no PR (§23)
                                    5b. default: write corrections + PR-on-change (§24)
```

1. **Argument validation** — the flag ladder above.

2. **Manifest gate (AC5).** Shared — defined once at
   `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#manifest-gate-shared-by-sync-release-seed-and-audit`
   (base-ref pre-check → checkout-independent resolution → silent no-op on genuine absence). `audit`
   is its **fourth** consumer; not re-derived here. If **absent** → **silent no-op**: no scan, no
   dispatch, no PR, no error, **no stdout**, exit 0 — for **both** `audit` and `audit --dry-run`.

3. **Dispatch `knowledge-engineer` (audit) — single dispatch, no confirm gate.** Pass the run mode
   (`--dry-run` or default), the resolved activated-row set, and `origin/<BASE-BRANCH>`. The dispatch
   performs the scan (§§20–22) and produces the findings report (§23).

4. **Scan + compute** (§§20–22): every activated row, partitioned by `generation-mode` into the
   deterministic-correction tier and the reference-integrity flag tier.

5. **Report / PR** (§23/§24):
   - **`--dry-run`** → print the report to stdout, open **no** PR, write nothing (AC3). Clean scan →
     `docs are in sync — no drift found`.
   - **default** → §24: ≥1 deterministic correction ⇒ write + embed report + open-or-update PR
     (only if `git status --porcelain` is non-empty); reference-integrity-flags-only ⇒ stdout report,
     no PR; clean ⇒ report clean, no PR.

Branch/PR mechanics (`docs/audit-<YYYY-MM-DD>`, the `Audit-Generated:` trailer, both re-run guards,
reset/force-push prohibition, the control-flow tail) live in §24 — not restated here.

## `distill ["<focus>"]` — special ADR route

`distill` is, like `seed adr`, a special route to `${CLAUDE_PLUGIN_ROOT}/refs/adr-pipeline.md` — not
a generic docs mode. It takes an **optional positional focus** after the `distill` mode token
(`/sdlc:docs distill ["<focus>"]`); everything after the mode token is the focus text, identical to
the old `--distill "<focus>"` semantics. **Empty focus means "whole corpus" — not an error**; the
`seed adr` empty-pattern STOP does **not** apply here. There is no `--distill` flag form.

Dispatch the **ADR pipeline (distill)** with an explicit **ADR dispatch-type signal** — **no**
manifest gate. Runs the two-phase dispatch defined in `refs/adr-pipeline.md`: Phase 1 mines the
learnings corpus and returns candidate ADR(s), proposed `agents:` tags, and the per-candidate
deletion list; the founder-confirmation gate at this command layer presents them (drafts and
deletions together — nothing is deleted the founder did not see and approve); Phase 2 writes
confirmed ADRs (`status: accepted`), deletes founder-approved learnings in the same PR, and
regenerates `docs/adr/index.md`. The two-phase split, the gate flow, and the `docs(adr):` branch/PR
naming are handed to the agent per `refs/adr-pipeline.md`'s §3a command-layer-flow section, not
restated here.

## Release branch/PR naming

- Branch `docs/release-<VERSION>`; PR title `docs(docs): release <VERSION>`. Cut from the **base
  branch head** (`origin/<BASE-BRANCH>`), **not** a story branch — release aggregates work already
  merged to base.

Full contract (cut point, commit string + trailer, PR base, local-branch precondition, both re-run
guards — including the prohibition on `reset --hard` / force-push, a deliberate divergence from §7
— and the control-flow tail) is defined once in
`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#13-release-mode--branch--pr--control-flow` — this
command does not re-derive it.

## Seed branch/PR naming

Defined once in `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md` §18. In summary: branch
`docs/seed-<type>-<SLUG>` (the **normalised** slug) cut from `origin/<BASE-BRANCH>` head — **not** a
story branch; commit and PR title `docs(docs): seed <type> <SLUG>`, carrying the trailer
`Seed-Generated: <type>/<SLUG>` that both re-run guards key on; PR base `<BASE-BRANCH>` from
project-context. `<type>` is in the branch name because two types may legitimately seed the same
topic. **The branch is never reset and never force-pushed** — a deliberate divergence from §7 (see
§18).

## Founder-confirm-gate authority note

Auto (deterministic) rows are written **un-gated** — they are computed in phase 1 and written in
phase 2 without a confirmation step, because they are fully derived and idempotent. Narrative
(how-to) drafts are written **only after explicit founder confirmation** at this command layer. A
dispatched subagent never runs the gate itself (it cannot pause for interactive input) — this
command owns it, exactly as it owns the gate for the `seed adr` and `distill` routes above.

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

After the phase-2 PR is raised, drive the review loop to convergence exactly as the ADR pipeline's
command-layer flow does:

```bash
/loop /sdlc:loop <PR_URL>
```

If the harness cannot nest `/loop` from inside a command, fall back to `ScheduleWakeup` to drive
`sdlc:loop`'s pass-cycle instead (same effect — the loop is the last thing the session does), then
let its final pass release. If the command hit a terminal STOP, WARNING, or no-op before a PR was
raised, release the session directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — for
exactly which pre-PR exit paths this covers, see the invoked mode's own control-flow tail:
`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#7-branch--pr-naming--control-flow` for `sync`,
`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#13-release-mode--branch--pr--control-flow` for
`release`, or `${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md#18-seed-mode--branch--pr--control-flow`
for `seed` — each lists a different pre-PR exit set (`sync`'s WARNING/no-op pair is not `release`'s
or `seed`'s no-op/STOP set).

## Error handling

| Scenario                                                                                                                                    | Behaviour                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `sync`/`release`/`seed <non-adr>`/`audit`, `.claude/project/docs-manifest.md` absent                                                        | **Silent** no-op — no branch, no dispatch, no PR, no error, **no stdout** (AC5). Distinct from a usage STOP, which prints. **Scoped to the four manifest-gated modes only** — `seed adr` and `distill` are special routes to `refs/adr-pipeline.md` with **no manifest gate** (see the `seed adr`/`distill` route sections above) and are never caught by this row, manifest present or absent. Match this row's scope **before** falling through to the generic table lookup: `seed adr`/`distill` never reach the manifest-gate check at all — they branch to the ADR pipeline earlier in the ladder, so there is no ordering ambiguity to resolve at runtime, only in how this table is read. |
| Empty `$ARGUMENTS` / unrecognised first token                                                                                               | Usage STOP (prints the usage message).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `sync` with missing/malformed story key (fails `^[A-Z][A-Z0-9]*-[0-9]+$`)                                                                   | Usage STOP (prints the usage message).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `sync`, no `origin/feat/<STORY-KEY>` or `origin/fix/<STORY-KEY>`, merged commit **found** on base                                           | Select the **merged-commit** diff source (§26) — diff `<sha>^..<sha>` (union across matches) and regenerate.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `sync`, no story branch, **zero** commits carry `<STORY-KEY>` on base                                                                       | **STOP** — `cannot locate a merged commit for <STORY-KEY> on origin/<BASE-BRANCH> — nothing to diff`. Never a silent no-op.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `sync`, no story branch, `git fetch` fails / `origin/<BASE-BRANCH>` unresolvable                                                            | **STOP** (shared with §1's base-ref pre-check) — never a fallthrough to "no diff".                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `refs/doc-types.md` unreadable/malformed                                                                                                    | Surface the failure and STOP — never regenerate from a partial registry.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Manifest present but no enabled `sync`-triggered row affected, and `llms.txt` unchanged                                                     | Clean no-op — no commit, no PR (AC6).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Deterministic regen produced byte-identical output and no narrative draft confirmed                                                         | No commit, no PR (AC6) — write phase detected an empty `git status --porcelain`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Founder rejects all narrative drafts but deterministic content changed                                                                      | Still commit + PR the deterministic regen (AC6 — content changed).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Story branch diff yields no changed files                                                                                                   | Only `llms.txt` is (re)generated; commit/PR only if it changed.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `gh` / `raise-pr.sh` failure                                                                                                                | STOP and surface — the write is on a branch and reviewable; never leave a raised-but-broken state silently.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `release` with missing/empty `<version>`                                                                                                    | Usage STOP (prints the usage message).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `release` with a `<version>` failing the token regex, or containing `..` / a path separator (e.g. `../../oops`)                             | Usage STOP stating **that** reason, raised **at the validation ladder** — before any branch, dispatch, draft, or founder gate.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `release` with a `<version>` ending `.lock` (e.g. `1.4.lock`)                                                                               | Usage STOP stating the `.lock` reason specifically — `VERSION.endswith(".lock")` is the test; git rejects the ref `docs/release-1.4.lock`, so it is caught up-front rather than at `git checkout` after the gate.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Manifest present but no `release`-triggered row enabled                                                                                     | Clean no-op — print `no release-triggered doc types enabled…`, no PR.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Manifest row absent for a release type (declined at `/init`, or deleted)                                                                    | Treated as **not enabled** — never inferred as default-on. Excluded from `ENABLED_ROWS`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Manifest enables only **some** release rows                                                                                                 | Not an error — only those rows are drafted, gated, and written. Disabled rows' pages are never created or touched.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| No stories merged in the range, `LAST_TAG` set, **and `LIKELY_KEYS = ∅`** (including the standards-only case)                               | Clean no-op — `no stories merged since <LAST_TAG> — nothing to release`, no PR.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| No stories merged in the range, no tags exist, **and `LIKELY_KEYS = ∅`** (including the standards-only case)                                | Clean no-op — `no stories merged since the start of history — nothing to release` (never an empty interpolation).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `PROJECT_KEYS = ∅` (no primary key, no additional keys)                                                                                     | **State A.** Emission uses NA-53's loose fallback with its existing risk note; the NA-60 warning overlay is **skipped entirely** — no computation, no no-op override. Never routed into a suppressing no-op.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `PROJECT_KEYS ≠ ∅`; emitted set `= ∅` **but** `OUT_OF_SCOPE ≠ ∅` **and** `LIKELY_KEYS = ∅` (out-of-scope tokens are all standards-prefixed) | **Not** the warning no-op — matches the clean-no-op row above instead (`LIKELY_KEYS = ∅` is the sole trigger condition). `STANDARDS_MATCHES` alone never suppresses "nothing to release" nor fires a warning with an empty key list.                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `PROJECT_KEYS ≠ ∅`; emitted set `= ∅` **and** `LIKELY_KEYS ≠ ∅`                                                                             | **Warning no-op** (pure silent-drop case — at least one genuine unrecognised key): name out-of-scope keys + enabled rows + section-aware remediation; never claim unqualified "nothing to release"; exit 0, no PR. Mutually exclusive with the clean-no-op rows above (both key off the single variable `LIKELY_KEYS`).                                                                                                                                                                                                                                                                                                                                                                          |
| `PROJECT_KEYS ≠ ∅`; emitted set `≠ ∅` **and** `LIKELY_KEYS ≠ ∅`                                                                             | Warning printed **alongside the drafts** at the confirm gate, before confirmation. Advisory — does not block.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `PROJECT_KEYS ≠ ∅`; emitted set `≠ ∅` **and** `LIKELY_KEYS = ∅` (whether or not `STANDARDS_MATCHES ≠ ∅`)                                    | Normal gate, no warning line (NA-53 unchanged) — a standards-only out-of-scope set never earns a warning line at the gate either.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Out-of-scope token matches a standards prefix (`UTF-8`, `SHA-1`, `RFC-2119`, …), **and `LIKELY_KEYS ≠ ∅` too**                              | Folded into the aggregated summary line **inside the already-firing warning**, which **names the distinct folded prefixes** (e.g. `RFC, SHA`) — **shown, not dropped**. If a listed prefix names a real project (`RFC-14`), the founder can add it. Never silently suppressed, never an anonymous count.                                                                                                                                                                                                                                                                                                                                                                                         |
| Out-of-scope tokens are **standards-prefixed only** (`LIKELY_KEYS = ∅`)                                                                     | No warning at all — see the `LIKELY_KEYS = ∅` clean-no-op / normal-gate rows above. `STANDARDS_MATCHES` is never shown as a standalone notice; it only ever appears as an addendum inside a warning that some genuine unrecognised key already triggered.                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| Warning remediation, `## Additional Jira project keys` section **present** in manifest                                                      | "Add the prefix(es) to the existing section."                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Warning remediation, section **absent** (upgraded repo)                                                                                     | "Add an `## Additional Jira project keys` section (comma-separated key list — see refs/docs-manifest-template.md)." Never reference a nonexistent section.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Founder commented out their keys in the section, or left the template's `<...>` example unreplaced                                          | §10 resolution ignores HTML comments, whitespace, and any `<...>`-bracketed placeholder → resolves to the empty additional-keys set (falls back to the primary key alone). Closes the copied-template-example hazard, not just hand-edited comments.                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Repo has no tags yet (full clone)                                                                                                           | Not an error — range is the **single-ended** `origin/<BASE-BRANCH>` (full history, root inclusive).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **Shallow clone**                                                                                                                           | Surface and STOP (`run: git fetch --unshallow`) — caught by the **positive** `git rev-parse --is-shallow-repository` pre-check, because a shallow clone with unreachable tags emits the _identical_ `No names found` text as a genuine first release.                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `git fetch` fails, or `origin/<BASE-BRANCH>` will not resolve                                                                               | Surface and STOP — resolved **before the manifest gate** (never mistaken for "manifest absent") and again **before** `git describe` (never mistaken for "no tags yet").                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Manifest present but the `llms-txt` row is disabled or absent (`release` **or** `seed`)                                                     | Not an error — `llms.txt` is a `sync`-triggered row, never a member of `ENABLED_ROWS` or the row `seed` was invoked for; both modes independently check its enabled state and do not write or touch it this run if disabled/absent. Any existing `llms.txt` is left as-is.                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `git describe --tags` fails with anything other than `No names found`                                                                       | Surface and STOP. `No names found` is the **only** fallthrough text, trusted only because the shallow pre-check already ran. `No tags can describe` is deliberately **not** matched.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `git log` failure                                                                                                                           | Surface and STOP — never silently release an empty or partial range.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| A commit body mentions `BREAKING CHANGE:` in prose rather than as a footer                                                                  | **Not** breaking — the test is line-anchored (`^BREAKING[ -]CHANGE:`), never a substring search.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `gh` unavailable / rate-limited                                                                                                             | Never affects written content — `gh` is display-only enrichment at the confirm gate. Output is byte-identical whether `gh` answers or not.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| A merged story has no motivating ADR                                                                                                        | Its release note omits the ADR link — never fabricated.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Repo has no `docs/adr/` directory                                                                                                           | Every release note is ADR-less; not an error.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| A **local** `docs/release-<VERSION>` holds commits not reachable from its remote                                                            | **STOP** (local-branch precondition) — never discard unpushed work, and never clobber it on the first-run path either.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Re-run: branch exists on `origin`, all page-touching commits carry the trailer                                                              | Not an error — check out at the remote head, write on top, commit + fast-forward push only if content changed. Never reset, never force-push.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Re-run: branch carries **out-of-pipeline** edits to generated pages (no `Release-Generated:` trailer)                                       | **STOP** (re-run content guard) — surface the paths and the PR number.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Re-run: a prior run's **founder gate edit** is present on a generated page                                                                  | **Re-derived**, not preserved and not STOPped — phase 1 re-drafts and the gate re-presents.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| Re-run: `## <VERSION>` already present in the cumulative changelog                                                                          | Not an error — the section is **replaced in place** (upsert), never prepended a second time.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Founder rejects every enabled draft and deterministic regen is byte-identical                                                               | No commit, no PR — write phase detected an empty `git status --porcelain`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `seed` with a missing `<type>`                                                                                                              | Usage STOP — usage message **plus** the valid type list.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `/sdlc:docs seed adr` / `seed adr ""` — empty pattern                                                                                       | **STOP** at the `seed adr` route with a usage message, before dispatching Phase 1. Never draft an ADR from empty input. Distinct from a no-op.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `/sdlc:docs seed adr "<pattern>"`                                                                                                           | Dispatch the ADR pipeline (seed) — **no** manifest gate, **no** type-activation gate. Draft → founder-confirm → write `docs/adr/NNNN-slug.md` (`status: accepted`) + regen index.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| First-ever ADR — `docs/adr/` does not exist                                                                                                 | `adr-pipeline.md`'s numbering step creates `docs/adr/` and bases `NNNN` at `0001`. Never a write into a missing dir or undefined numbering.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `seed` with an unknown `<type>`                                                                                                             | Usage STOP naming the passed type and enumerating the **resolved** `SEED_TYPES` (rendered, never a hardcoded literal).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `<topic>` slugs to empty (`...`, `@{`, `日本語`, `☕`)                                                                                      | Usage STOP — `must contain at least one ASCII letter or digit`. Says **ASCII** deliberately: a non-ASCII topic _is_ letters, and a message claiming otherwise would misdescribe the input.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `<topic>` slugs to more than 80 characters                                                                                                  | Usage STOP naming the derived length. **Never truncated** — truncation would collide two distinct topics onto one branch/page and silently overwrite one.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `<topic>` slugs to a reserved page id (`seed concept index`)                                                                                | Usage STOP at the ladder, **naming the slug but not the `target-path`** (unresolved at that point). Without it the run destroys its own output: phase 2 writes `docs/concepts/index.md`, then the index regen fires **because that page now exists** and rewrites the founder's page as a generated index in the same commit.                                                                                                                                                                                                                                                                                                                                                                    |
| `<topic>` contains `..`, `/`, `.lock`, or trailing `.`/`-`                                                                                  | **Not an error** — slugification's `[a-z0-9-]` charset removes them (`../../oops` → `oops`). No rejection rule exists for these, deliberately: each would be **vacuous**. The docs tree cannot be escaped via the slug.                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `target-path` ends in `/` (every registry default does) and `PAGE` is joined naively                                                        | **Silent destruction of a published page** — `git show` fails on `docs/concepts//x.md` so the gate reports "first run", while the filesystem collapses `//` and phase 2 overwrites the real file. Both verified. Closed by normalising `target-path` before the join (§16).                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `<topic>` omitted                                                                                                                           | Not an error — the founder is prompted **after** the manifest and type-activation gates, and the answer runs the **identical** validation ladder as a supplied topic.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Requested `<type>`'s manifest row absent or `enabled = false`                                                                               | Treated as **not activated** — never inferred as default-on. Report + **no write** (AC2). Informational, **not** silent: the manifest exists, so the founder opted in.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `refs/doc-types.md` unreadable/malformed                                                                                                    | Surface the failure and STOP — never resolve `SEED_TYPES` from a partial registry, and never fall back to a hardcoded list.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `<PAGE>` already exists at `origin/<BASE-BRANCH>`                                                                                           | **STOP** — `seed` is a create verb; a published page may carry hand edits and a founder-authored `source:` list. Never overwritten.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Founder rejects / does not confirm at the gate                                                                                              | Write nothing; report and exit cleanly — no branch, no PR, no phase-2 dispatch. Unlike `release`, there is no deterministic half worth committing.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Founder confirms a page missing `title` or `description` frontmatter                                                                        | Caught **at the gate**, where the content still exists and the founder fixes the line in place. **Not** a phase-2 STOP: phase 2 holds an opaque payload and could only discard a fully authored page over a one-line defect.                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| A **pre-existing** enabled `public: yes` page lacks `title`/`description` during the regen                                                  | **Skipped and surfaced** (path in phase-2 output + PR body) — never a STOP (which would tear the write: page committed, index not), and never inferred from body/filename (which would fabricate published index copy).                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Founder omits `source:` on a seeded `how-to` / `integration-guide`                                                                          | Not an error — the key is **omitted entirely** (never written empty). Per §5 the page is simply never auto-refreshed. `seed` never infers globs.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| claude-mem tools unavailable                                                                                                                | **Never a halt for `seed`** — phase 1 proceeds without corpus enrichment and says so at the gate. (Contrast `distill`, which halts: the corpus is `seed`'s enrichment but `distill`'s entire input.)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `<type>` is `tutorial` and the corpus is available                                                                                          | Not consulted — `tutorial`'s registry `source-of-truth` is `founder-authored` only.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| No section index page exists at `SEED_ROW`'s `target-path`                                                                                  | Not an error — `llms.txt` is the sole index; no separate section index is created. The existence test reads the **pre-write** tree, so a page this run wrote can never satisfy it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Re-run: branch carries **out-of-pipeline** edits to generated pages (no trailer)                                                            | **STOP at step 5**, before the founder authors — surface the paths and the PR number. Never overwritten. The scanned path set is `PAGE` **plus** `llms.txt` (when enabled) **plus** any regenerated section index page.                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| A guard condition first becomes true **while the founder is authoring** (TOCTOU)                                                            | Phase 2 **MUST** re-check and STOP — but **MUST preserve the confirmed content** (session temp dir, path surfaced in the STOP), never discard it. The re-check is **mandatory, not optional**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| A **local** `docs/seed-<type>-<SLUG>` holds commits not reachable from its remote                                                           | **STOP** (local-branch precondition, evaluated at step 5) — never discard unpushed work.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `audit` with an unrecognised argument (`--dryrun`, `foo`, `--dry-run extra`)                                                                | Usage STOP — `unknown argument for audit — usage: /sdlc:docs audit [--dry-run]`. Never silently treated as a plain `audit`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `audit` / `audit --dry-run`, `.claude/project/docs-manifest.md` absent                                                                      | **Silent** no-op — no scan, no dispatch, no PR, no error, **no stdout** (AC5). Distinct from a usage STOP, which prints.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `audit`, manifest present but no row activated                                                                                              | Clean scan — report `no activated doc types to audit`; no PR. Informational, not silent.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `refs/doc-types.md` unreadable/malformed (audit)                                                                                            | Surface and STOP — never audit against a partial registry, never fall back to a hardcoded row list.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `--dry-run`, drift found                                                                                                                    | Print the findings report; **no** write, **no** PR (AC3).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| default, ≥1 deterministic correction (audit)                                                                                                | Write regenerated `auto` pages, embed the full findings report in the PR body, open-or-update the PR (AC2).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| default, drift is **only** reference-integrity flags                                                                                        | Report the flags to stdout; **no PR** — nothing mechanical to commit, a narrative fix is never fabricated.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| default, no drift of either tier (audit)                                                                                                    | Report clean; open nothing (AC2).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| A narrative page diverges from an ADR it references                                                                                         | **Flagged** as "the doc diverges from the ADR" (AC4) — ADR is source of truth, direction fixed, **never** written into `docs/adr/`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| A narrative page's `.md`/`.mdx` link target does not resolve file-relative from the page's own directory                                    | **Flagged** as `dangling-link` — deterministic path-existence check; external, `mailto:`, and pure-anchor links are skipped, and a link's `#fragment` is stripped before resolving (only file existence is checked). **Never** rewritten or auto-corrected.                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| Re-run: audit branch carries out-of-pipeline edits (no `Audit-Generated:` trailer)                                                          | **STOP** (re-run content guard) — surface the paths + PR number; never overwritten.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `distill`, claude-mem tools **absent**                                                                                                      | **HALT** — `claude-mem tools unavailable — /sdlc:docs distill requires the claude-mem plugin; install it or use seed adr`. **Not** softened to `seed`'s "continue without corpus" path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `distill`, claude-mem tools present but **DB empty**                                                                                        | Non-fatal — continue on repo-native citations; note the empty DB. Distinct from the tools-absent halt.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `distill`, **no promotable candidates**                                                                                                     | Clean no-op (AC6) — report "no candidates met the promotion criteria", open **no** PR, exit cleanly. Distinct from the tools-absent halt and from a git/`gh` STOP.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |

Mode + args:
$ARGUMENTS
