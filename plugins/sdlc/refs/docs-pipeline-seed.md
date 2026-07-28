# Docs pipeline — seed mode (§§15–19)

**Mode-specific slice for `/sdlc:docs seed`.** Type resolution + topic/slug validation, the gate
ladder + `PAGE` construction, page artifacts + frontmatter, branch/PR/control flow, and no-op +
re-run semantics. Read together with the shared foundation slice, `docs-pipeline-core.md` (§§1–9)
— this slice does not restate the manifest gate, the two-phase dispatch split, or the deterministic
regen algorithm, it only points back to them. A handful of illustrative cross-mode comparisons also
point at `docs-pipeline-release.md` (§§10–14) — `seed` does not depend on release's machinery to
run, but explains a couple of its own rules by contrast with it.

## 15. Seed mode — type resolution + topic validation

### `SEED_TYPES` — registry-derived, never hardcoded

`SEED_TYPES` resolves **at read time** from `refs/doc-types.md`: every row whose `trigger` cell
contains the `seed` token, **minus `adr`** (routed to `refs/adr-pipeline.md`, not the generic seed
machinery). Today that resolves to `concept`, `tutorial`, `integration-guide`, and `how-to`.

**Why derived and not a literal list in `docs.md`.** `refs/doc-types.md` is the stated single source
of truth for `trigger` (`docs-manifest-template.md`: consumers "derive all four from
`refs/doc-types.md` at read time"). A hardcoded list would be a second copy of a normative fact and
would drift the moment a row's `trigger` changes. `seed` reads the registry; the registry decides.
Any message that enumerates the valid types **renders the resolved `SEED_TYPES`** — it never types
the list as a literal, or it becomes the copy this rule exists to avoid.

`refs/doc-types.md` unreadable or malformed → surface the failure and **STOP**. Never resolve
`SEED_TYPES` from a partial registry, and never fall back to a hardcoded list.

**`adr` is excluded from `SEED_TYPES` rather than admitted-then-rejected downstream**, so no `adr`
run can reach the manifest gate, the branch, or the write path. `seed adr` is a **special route**
to `refs/adr-pipeline.md` (`commands/docs.md` step 7), not a generic `SEED_TYPES` member — an ADR
is a numbered `docs/adr/NNNN-slug.md` file, not a single narrative page.

### Topic validation + slug normalisation

`<topic>` is founder prose. `SLUG` is derived from it, and `SLUG` — not the raw topic — forms a git
branch name (`docs/seed-<type>-<SLUG>`) and a file path (`PAGE`, §16).

```text
SLUG = slugify(topic):
  1. trim, lowercase
  2. replace every run of characters outside [a-z0-9] with a single "-"
  3. collapse repeated "-", then strip leading and trailing "-"

SLUG must additionally satisfy, or the run STOPs:
  - non-empty
  - no longer than 80 characters
  - not a reserved page id (see below)
```

**The ladder is one rule with two entry points, and both go through it.** A supplied `<topic>` and a
prompted `<topic>` are validated and slugged by the **same** rule. A ladder applied only to the CLI
argument would be trivially bypassed by omitting the argument and typing the same hostile string at
the prompt — validation the primary input path never reaches is not validation.

**Normalisation is identity-forming, not cosmetic.** `Offline Sync`, `offline-sync`, and
`  Offline   Sync!  ` all slugify to the same `SLUG` (`offline-sync`) — one branch, one PR, one page
— rather than three parallel branches and three duplicate pages for one topic.

| Raw `<topic>`        | `SLUG`         | Note                                  |
| -------------------- | -------------- | ------------------------------------- |
| `My Topic`           | `my-topic`     | —                                     |
| `my-topic`           | `my-topic`     | identical to the above — one identity |
| `  Offline   Sync  ` | `offline-sync` | whitespace runs collapse              |
| `../../oops`         | `oops`         | traversal characters cannot survive   |
| `a/b/c`              | `a-b-c`        | path separators cannot survive        |
| `1.4.lock`           | `1-4-lock`     | see the `.lock` note below            |
| `x..y`               | `x-y`          | `..` cannot survive                   |
| `@{`                 | _(empty)_      | → STOP                                |
| `...` / `----` / `-` | _(empty)_      | → STOP                                |
| `日本語` / `☕`      | _(empty)_      | → STOP                                |

**Three failure modes are reachable, and all three are real. Do not add a fourth.** The slugify
charset is `[a-z0-9-]`, which makes several rules that look like they belong here — by analogy with
`docs-pipeline-release.md` §13's version ladder — **structurally vacuous**. A vacuous rule is not free: NA-53 shipped a `.lock`
check that rejected nothing and an unreachable trailing-`-` STOP whose message misdescribed its
input, and both survived review because nobody tested them. So, explicitly:

- **No `..` rule.** `.` is not in the charset; `x..y` → `x-y`. Unreachable.
- **No `.lock` rule.** `1.4.lock` → `1-4-lock`. Verified:
  `git check-ref-format --branch docs/seed-concept-1-4-lock` → **valid**. A `SLUG` cannot end in
  `.lock` because it cannot contain a `.`. Unreachable. (`docs-pipeline-release.md` §13 needs this rule; `seed` does not.
  **Do not add it "for parity".**)
- **No trailing `.`/`-` rule.** Step 3 strips them. `topic-` → `topic`, `topic.` → `topic`.
  Unreachable.
- **No path-separator rule.** `/` is not in the charset. Verified: `../../oops` → `oops`. The docs
  tree cannot be escaped by construction — a stronger guarantee than a rejection regex, because no
  input reaches the write path unsanitised. **This guarantee governs the slug; it does NOT extend to
  the `target-path` the slug is joined to — see §16's `PAGE` construction.**

The three rules that **are** reachable:

- **Empty `SLUG`** → STOP. Reachable two ways — punctuation-only input (`...`, `@{`) and
  **non-ASCII-only input** (`日本語`, `☕`), both verified empty:

  ```text
  invalid topic "<raw>" — must contain at least one ASCII letter or digit
  (the page id and branch name are derived from it)
  ```

  Say **ASCII letter or digit**, not "letters or digits": `日本語` _is_ letters, and a message
  claiming otherwise would misdescribe the input in front of the founder — exactly what NA-53's
  unreachable trailing-`-` STOP got wrong.

- **`SLUG` longer than 80 characters** → STOP:

  ```text
  invalid topic "<raw>" — the derived page id is <n> characters; shorten the topic to 80 or fewer
  ```

  Empirically grounded: a 300-character filename fails `ENAMETOOLONG` on this repo's filesystem
  while a 200-character one succeeds — verified. **STOP rather than truncate**, deliberately:
  truncation would map two distinct long topics onto one `SLUG` → one branch, one page, one silently
  overwriting the other.

- **`SLUG` is a reserved page id** → STOP. The reserved set is **`{index}`**:

  ```text
  invalid topic "<raw>" — "<SLUG>" is a reserved page id: it is the section index
  this run regenerates. Choose a different topic.
  ```

  **The message deliberately does not name the `target-path`.** This STOP fires at the ladder, where
  `target-path` is not yet knowable (§16 step 3 resolves it). Interpolating the **registry default**
  would print `docs/concepts/` when the founder retargeted the row to `docs/explain/` — naming a path
  the run would never write. Relocating the check to obtain the value would silently move a rule that
  belongs at the ladder. The reserved id is a property of the **slug**, not the path, so the message
  stays about the slug.

  This is **not** a charset rule — `index` is a perfectly well-formed slug. It is a **collision**
  rule, and without it `seed concept index` destroys its own output inside a single run: `PAGE`
  resolves to `docs/concepts/index.md`, the page-exists gate passes (no index page exists yet, so it
  looks like a legitimate first seed), phase 2 writes the founder's page there, and **the index regen
  then fires because phase 2 just created a section index page at that `target-path`** — rewriting
  the founder's page as a generated index in the same commit.

  **Two independent rules close this, and both are required (each covers the other's gap):** this
  STOP, and §19's rule that the index-regen existence test reads the **pre-write** tree. Neither is
  redundant.

**`SLUG` (normalised), not the raw topic, is used everywhere downstream** — branch name, PR title,
commit string, page id, and the page-exists gate. The raw topic is echoed **only** in the STOP
messages above, and used verbatim **only** as the human topic handed to phase 1 for drafting.

All of these are **usage STOPs raised at the ladder** — before any branch, dispatch, draft, or
founder gate.

## 16. Seed mode — gate ladder + `PAGE` construction

The seed run reuses `docs-pipeline-core.md` §2's two-phase dispatch and command-layer founder-confirm gate — **not
re-derived here**. What is seed-specific, **in this order** (the order is load-bearing):

```text
1. argument validation (§15)  →  2. manifest gate (`docs-pipeline-core.md` §1)  →  3. type-activation gate
→  4. topic prompt (if omitted)  →  5. page-exists + branch-state gate (§18's precondition
   + BOTH re-run guards)  →  6. phase 1 (scaffold, writes nothing)  →  7. founder gate (authoring)
→  8. phase 2 (write + regen + commit/PR)
```

**Everything through step 5 runs before the founder authors anything, and that is the ordering
principle for the whole ladder.** For `seed`, a post-gate STOP does not merely waste a machine's
work as it would in `sync` or `release` — **it destroys the founder's entire page**. Every rejection
whose inputs are already available runs **before** the gate; where one cannot be, it must preserve
the authored content rather than discard it (§18).

1. **Argument validation** — §15's ladder, including a supplied `<topic>`. A supplied topic is
   validated **before** gates 2–3 because it forms a branch name and a path.

2. **Manifest gate (AC5)** — shared with `sync` and `release`; defined **once** in
   [`docs-pipeline-core.md` §1's Manifest gate](docs-pipeline-core.md#manifest-gate-shared-by-sync-release-seed-and-audit). `seed` is its third
   consumer and does **not** re-derive it. The base-ref pre-check ordering is load-bearing for
   exactly the reason `docs-pipeline-release.md` §14 documents: a bare `git show origin/<BASE-BRANCH>:<path>` failure is
   ambiguous between "the manifest genuinely does not exist" (the intended silent no-op) and "the
   **ref** does not resolve" (a fresh/shallow CI clone, a renamed base branch). Without the
   `git fetch` + `git rev-parse --verify origin/<BASE-BRANCH>^{commit}` pre-check running **first**,
   an opted-in repo with a real manifest gets a **silent no-op reporting success while writing
   nothing**. Manifest genuinely absent → **silent no-op**: no prompt, no branch, no dispatch, no PR,
   no error, **no stdout**, exit 0.

3. **Type-activation gate (AC2).** Resolve the requested `<type>`'s row from the manifest; call it
   `SEED_ROW`. The type is **activated** iff its row is **present** in the manifest row-table **and**
   its `enabled` column is `true`.
   - **Absent is never activated.** A row **present** is enabled per its `enabled` column
     (`docs-manifest-template.md`'s Fill rules default it to `true` for every _written_ row). A row
     **absent** is **not** activated. Absence has two causes and the distinction does not matter
     here: the type was offered at `/init` and declined (recorded as a `<!-- declined: <type> -->`
     comment, which never writes a disabled row), or the row was deleted (a future re-init may
     re-offer it — `/init`'s business, not `seed`'s). **Never infer a missing row as enabled.**
   - **Not activated (absent _or_ `enabled = false`) → report and make no write**, before any prompt,
     branch, dispatch, or draft:

     ```text
     doc type "<type>" is not activated in .claude/project/docs-manifest.md — nothing seeded
     (add or enable its row to seed this type)
     ```

     **Informational, not silent** — the manifest exists, so the founder opted in; a request for a
     specific, deactivated type is worth surfacing. Deliberately distinct from step 2's silent no-op.
     Do not dispatch `knowledge-engineer`.

   - **`target-path` comes from `SEED_ROW`, not from the registry default.** The registry's
     `target-path` is a default token that `/init` pre-fills and the founder retargets; the manifest
     row is authoritative at read time.

4. **Topic resolution (prompt if omitted).** If `<topic>` was not supplied, prompt for it **now** —
   at the command layer, the only layer that can pause for input — and run the **identical** §15
   ladder on the answer. A prompted topic that fails is the same usage STOP as a supplied one.
   Placed **after** gates 2–3 so a repo with no manifest is never prompted before its silent no-op,
   and a deactivated type is reported rather than prompted for.

5. **Page-exists + branch-state gate — all of it pre-gate.** Resolves `PAGE`, decides first-run vs
   re-run, and runs **every** guard that could reject the run. All inputs (base ref, branch state on
   `origin`, commit trailers) are available now; none requires the founder's content.

   **Construct `PAGE` by normalising `target-path` first — the naive join fails OPEN.**

   ```text
   PAGE = rstrip(SEED_ROW.target-path, "/") + "/" + SLUG + ".md"
   ```

   Every registry `target-path` ends in `/` (`docs/concepts/`, `docs/tutorials/`, …), and a
   founder-retargeted one may or may not. A plain `<target-path> + "/" + <SLUG> + ".md"` yields
   `docs/concepts//offline-sync.md`. That is **not cosmetic** — it silently defeats this gate,
   because git and the filesystem **disagree** about the path:
   - `git show "origin/<BASE-BRANCH>:docs/concepts//offline-sync.md"` **does not resolve**, even
     when `docs/concepts/offline-sync.md` is published — git matches tree paths literally and there
     is no empty-named subtree. **Verified against this repo.**
   - The **filesystem collapses `//`** — writing `docs/concepts//offline-sync.md` opens
     `docs/concepts/offline-sync.md`. **Verified.**

   The gate is on the losing side of that disagreement: it concludes "exists nowhere → first run",
   phase 1 scaffolds, and phase 2 writes through the malformed path **onto the published file**,
   destroying it — the exact outcome this gate exists to prevent, with no STOP and no diff the
   founder would recognise as a delete. And because **every** registry `target-path` ships with a
   trailing slash, this is the **default** path, not an edge case.

   **Normalise once, at construction. The same `PAGE` string is then used everywhere downstream** —
   the gate, phase 1, phase 2's write, and the guard path set — **never re-joined per call site** (a
   second join is a second chance to reintroduce the defect). This is a defect-closing rule, not a
   style preference — **do not "simplify" it away.**

   **Check `PAGE` checkout-independently** at the base ref — never the working tree, for the same
   reason the manifest is read that way (a stale local checkout must not decide whether a page
   exists):

   ```bash
   git show "origin/<BASE-BRANCH>:$PAGE" >/dev/null 2>&1
   ```

   The base ref is already known to resolve (step 2's pre-check ran), so a failure here is
   unambiguous — the path does not exist at a known-good ref. Therefore:
   - **Exists at `origin/<BASE-BRANCH>`** → **STOP**:

     ```text
     <PAGE> already exists on <BASE-BRANCH> — seed authors new pages, it does not rewrite published
     ones. Edit the page directly, or re-seed under a different topic.
     ```

     `seed` is a **create** verb. Silently overwriting a published page — one that may carry months
     of hand edits and, for a `how-to`, a founder-authored `source:` list — is not scaffolding.

   - **Does not exist at base, but the seed branch exists on `origin`** → a **re-run** of an unmerged
     seed. Allowed — **but §18's local-branch precondition and both re-run guards are evaluated
     now, here, before phase 1 dispatches.**
   - **Exists nowhere** → first run. **The local-branch precondition still runs** — it applies on
     every path (a local branch of the same name with unpushed commits says nothing about `origin`).

6. **Phase 1 dispatch — scaffold & draft, writes nothing.** Inputs: `<type>`, `SEED_ROW` (its
   `target-path`), `SLUG`, the **raw** topic text, the normalised `PAGE`, and `origin/<BASE-BRANCH>`.
   Phase 1 loads `writing-docs` **unconditionally**, selects the quadrant template for `<type>`'s
   registry `quadrant` (§17), scaffolds the page filling only what the topic and (for corpus-backed
   types) the learnings corpus support — **never inventing facts to fill a section** (`writing-docs`'
   "No TBDs in published docs" rule applies, so an unsupported section is left for the founder rather
   than padded with plausible prose) — emits §17's required frontmatter, and returns the scaffold.
   **Nothing is written to disk in phase 1.**

7. **Founder-confirm gate (command layer, AC3) — this is where the founder authors.** Present the
   scaffold; the founder may **accept, edit, author over, or reject** it. Unlike `sync`/`release`,
   where the gate mostly confirms machine-derived content, **here the gate is the authoring
   surface**, and heavy editing is the expected path, not the exception. `tutorial` is `manual-only`
   in the registry — the scaffold is a skeleton and the prose is the founder's.
   - **Validate the confirmed content here, at the gate, while it still exists** — specifically §17's
     required `title`/`description` frontmatter. The gate is the **last** layer that holds the
     founder's content in an editable, interactive context; phase 2 is a fresh dispatch that receives
     it as an opaque payload. A content check deferred to phase 2 can only STOP — it cannot ask the
     founder to fix the missing line — converting a one-line correction into the loss of a whole
     authored page.
   - **"Present" is not "filled."** A `title`/`description` that is **missing** and a
     `title`/`description` that **still carries the `writing-docs` scaffold's unfilled
     `TODO(fill)` sentinel** are the **same rejection** at this gate — reject/re-prompt in either
     case; a confirmed-but-unedited placeholder is never treated as valid content. (A
     `TODO(fill)`-still-present `related-adrs:` value cannot occur — the key's own default is `[]`,
     not a sentinel — so this check is scoped to `title`/`description`, plus, when the row is
     `how-to`/`integration-guide` and `source:` is **present**, its list item(s): reject a `source:`
     whose only entry is still the scaffold's own `TODO(fill)` glob example, since a `source:` list
     holding no real glob can never intersect `CHANGED_FILES` and would silently defeat `docs-pipeline-core.md` §5's
     auto-refresh the founder believed they'd opted into. A `source:` key that is **absent** is
     unaffected — omission is the documented opt-out, not a defect.)
   - **Founder rejects / does not confirm** → write nothing, no branch, no PR, no phase-2 dispatch;
     report and exit cleanly. Unlike `release`, a seed run has **no** deterministic half that could
     still be worth committing — the index/`llms.txt` regen is a _consequence_ of the page write, so
     with no page there is nothing to reindex.
   - `gh` and the learnings corpus **MAY** enrich what is displayed here; neither may feed a written
     byte except through the founder's confirmation (§19).

8. **Phase 2 dispatch — write confirmed, fresh dispatch.** Inputs: `<type>`, `SEED_ROW`, `SLUG`, the
   normalised `PAGE`, and the founder-confirmed content **verbatim** (inline or via
   `scripts/tmp-dir.sh` temp files by path — **never re-derived**; phase 2 is a fresh dispatch with
   no visibility into phase 1 or the gate). Phase 2 checks out per §18, **re-verifies the
   precondition and both guards as a mandatory TOCTOU backstop** (§18), writes the confirmed content
   to `PAGE` and **only** to `PAGE` — `seed` writes exactly one page for exactly one row, the seed
   instance of `docs-pipeline-core.md` §3's "never touches an unaffected row's pages" invariant — regenerates the index +
   `llms.txt` per §19, and commits/pushes/PRs **only if `git status --porcelain` on the written paths
   is non-empty**.

## 17. Seed mode — page artifacts + frontmatter

Each type maps onto an existing `writing-docs` quadrant template via its **registry `quadrant`** —
a lookup, not a new table to maintain:

| `type`              | Registry quadrant | `writing-docs` template | Default `target-path` | File convention | `source:` key                   |
| ------------------- | ----------------- | ----------------------- | --------------------- | --------------- | ------------------------------- |
| `concept`           | explanation       | Explanation             | `docs/concepts/`      | `<SLUG>.md`     | N/A (not a how-to page)         |
| `tutorial`          | tutorial          | Tutorial                | `docs/tutorials/`     | `<SLUG>.md`     | N/A (not a how-to page)         |
| `integration-guide` | how-to            | How-to                  | `docs/integrations/`  | `<SLUG>.md`     | Offered at the gate — see below |
| `how-to`            | how-to            | How-to                  | `docs/how-to/`        | `<SLUG>.md`     | Offered at the gate — see below |

One page per seed run, always a **new** page (§16's page-exists gate). The `target-path` is
`SEED_ROW`'s, not the registry default, and is **trailing-slash-normalised before the join** (§16).

### Page frontmatter (required — `llms.txt` reads it)

Every seeded page **MUST** carry:

```yaml
---
title: <human title for the page>
description: <one line, used verbatim as the llms.txt description>
---
```

**As of NA-61 the `writing-docs` templates emit this frontmatter** — all four Diátaxis templates
(Tutorial, How-to, Reference, Explanation) now carry `title:` + `description:` (bracket-free
`TODO(fill)` scalars the author fills) + `related-adrs: []`. A page authored from a current template
therefore carries the **keys** by construction — but "carries the key" and "is actually filled in"
are different claims, and only the second one satisfies this requirement. The seed layer still
**validates** it at the founder-confirm gate (below) rather than assuming it, because (1) a
**legacy or hand-authored** page — or one written before NA-61 — may still lack the key entirely, and
(2) a current-template page the founder confirmed **without editing** still carries the unfilled
`TODO(fill)` sentinel — present, but not a real title/description. The gate rejects **both**
shapes; the requirement is enforced on the page `seed` writes, not waived by the template's own
scaffolding.

The consequence: `docs-pipeline-core.md` §8's `llms.txt` regen derives every entry from the page's frontmatter
(`title — one-line description — relative link`). A seeded page with no frontmatter either **drops
out of `llms.txt` silently** — published but invisible to the index that exists to expose it, the
exact failure `seed` prevents — or makes the regen fail on a page it expects to carry frontmatter. A
seeded page whose frontmatter is **present but still `TODO(fill)`** is **worse**, not merely
equivalent: an absent-frontmatter page is loudly skipped-and-surfaced by §19 below, but a
present-and-unfilled one would satisfy a naive presence check and ship the literal sentinel text into
the public index — silently, and strictly worse than the pre-NA-61 state the skip already handled
loudly. The gate below closes exactly this gap.

**Where the check lives is itself load-bearing:** phase 1 emits the frontmatter; **the command layer
validates it at the founder-confirm gate**, where the content still exists and the founder can fix a
missing line — or an unedited placeholder — in situ. It is **NOT** deferred to phase 2 — a fresh
dispatch holding an opaque payload, which can only STOP, losing a four-hundred-line authored page to
a one-line defect and reintroducing the "STOP after the founder has authored" failure this rule
exists to prevent. Phase 2 MAY keep a defensive assertion, but it **must preserve the content**
(session temp dir + surfaced path) rather
than discard it.

### `source:` frontmatter — `how-to` and `integration-guide` only

Both map onto the how-to quadrant, whose template emits a `source:` glob list. `docs-pipeline-core.md` §5 is normative and
unchanged: a how-to page **with** `source:` is auto-refresh-drafted by `sync` when `CHANGED_FILES`
intersects its globs; a page **without** it is **never** auto-refreshed — the deliberate opt-in
boundary. `seed` **is** that founder action, and the natural moment to make the choice:

- The scaffold presents the `source:` list (with the template's explanatory comment) at the gate, and
  the founder supplies globs or removes the key.
- **Founder supplies globs** → the page is written with `source:`; future `sync` runs draft refreshes
  of it. This is the seed → sync handoff that makes `how-to`'s `seed,sync` trigger coherent.
- **Founder omits it** → the key is **omitted entirely** (never written empty). Per `docs-pipeline-core.md` §5 the page is
  simply never auto-refreshed. Not an error, and **not something `seed` may infer a value for** —
  inferring globs would opt the founder into automated refreshes of a page they hand-authored.
- `concept` and `tutorial` pages **never** carry `source:` — it is a how-to-quadrant key and `docs-pipeline-core.md` §5's
  match semantics apply only to how-to rows. Do not emit it for them.

## 18. Seed mode — branch / PR / control flow

> **Divergence from `docs-pipeline-core.md` §7 — do not harmonise.** `docs-pipeline-core.md` §7 (`sync`) resets the branch onto regenerated state
> and force-pushes with `--force-with-lease`, safe there because `sync`'s branch content is **fully
> derived**. A seed branch is the opposite extreme: its content is **founder-authored** _and_ the
> control-flow tail drives `/loop /sdlc:loop` against it, so it carries review-fix commits.
> `reset --hard` and force-push are **prohibited** on seed paths.

**All of the precondition and guard rows below are evaluated at [§16 step 5](#16-seed-mode--gate-ladder--page-construction) — before phase 1 dispatches and before the founder authors anything.**
They are defined here and evaluated there. Every input they need (base ref, branch state on `origin`,
the trailer on each commit) is available at step 5; none needs the founder's content. Deferring any
of them to phase 2 would mean a STOP that discards the founder's authored page to protect a condition
knowable before they typed a word. **Phase 2 re-runs them as a mandatory TOCTOU backstop before
writing** (the branch can move while the founder authors), preserving the confirmed content if one
fires.

| Item                      | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Branch                    | `docs/seed-<type>-<SLUG>` (the **normalised** slug — `My Topic` and `my-topic` resolve to the same branch, never two), cut from the **base branch head** (`origin/<BASE-BRANCH>`) — **not** a story branch. A seed authors a new page against current base; there is no story diff to read. Mirrors `refs/adr-pipeline.md`'s §3a `docs/adr-<slug>` shape, with `<type>` included because two types may legitimately seed the same topic (`docs/seed-concept-offline-sync` and `docs/seed-tutorial-offline-sync` are distinct pages and must be distinct branches).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Commit                    | `docs(docs): seed <type> <SLUG>` (via `conventional-commit`), carrying the trailer `Seed-Generated: <type>/<SLUG>`. **The trailer is load-bearing**, not decoration: it is the only reliable marker of "this pipeline wrote this commit", and both guards below key on it. Subject-matching is not a substitute.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| PR title                  | `docs(docs): seed <type> <SLUG>`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| PR base                   | `<BASE-BRANCH>` from project-context (never assume `main`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Local-branch precondition | Applies on **every** path, first-run and re-run alike, evaluated at §16 step 5. If a **local** `docs/seed-<type>-<SLUG>` exists holding commits not reachable from `origin/docs/seed-<type>-<SLUG>` (or, when no such remote exists, any commits at all beyond `origin/<BASE-BRANCH>`) → **STOP**: `local branch docs/seed-<type>-<SLUG> has unpushed commits; push, drop, or rename it, then re-run.` Never `checkout -B` over it. Hoisted out of the re-run rows deliberately: the first-run path is defined by the branch being absent **on `origin`**, which says nothing about a local branch of the same name.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| First-run PR              | No remote branch (`git rev-parse --verify origin/docs/seed-<type>-<SLUG>` fails) → after the precondition passes, create the branch from `origin/<BASE-BRANCH>` head, write, commit, push, open the PR (`gh pr create`) against `<BASE-BRANCH>`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Re-run behaviour          | **Open or update; the branch's commits are never rewritten.** If the branch exists on `origin` → `git fetch origin`, run the precondition + **both guards at §16 step 5**, then (in phase 2) re-verify them and check it out **at its remote head**: `git checkout -B docs/seed-<type>-<SLUG> origin/docs/seed-<type>-<SLUG>` — **the single normative flow**. Write the confirmed content **on top** as a new commit and `git push` (plain fast-forward). A re-run where nothing changed produces **no commit, no push, no duplicate PR**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Re-run history guard      | The **one forbidden path**: no re-run may reset the branch onto regenerated state, force-push it (`--force` / `--force-with-lease`), or discard any commit reachable from `origin/docs/seed-<type>-<SLUG>`. A reset-to-fresh + `--force-with-lease` would _succeed_ (the local ref was just fetched) and silently revert the PR to unreviewed content. Checking out at the remote head does none of these.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Re-run content guard      | Preserving commits protects **history**; this guard protects **content**. Evaluated at §16 step 5, and **re-verified by phase 2 before writing** — mandatory, because phase 2 is the only layer that writes and the branch can move while the founder authors. Find commits on the branch (relative to `origin/<BASE-BRANCH>`) that touch **any path phase 2 writes this run** and **lack the `Seed-Generated: <type>/<SLUG>` trailer**. **That path set is NOT just `PAGE`**: phase 2 also rewrites `llms.txt` (when its row is enabled) and any regenerated section index page — a `/sdlc:loop` review-fix or founder edit to either is exactly the out-of-pipeline content this guard protects, and scoping the scan to `PAGE` alone would silently destroy it with no STOP. If any qualifying path is found → **STOP**: `branch docs/seed-<type>-<SLUG> carries edits to generated pages (<paths>) that this pipeline did not write; re-running would overwrite them — merge or close PR #<n>, or drop those edits, then re-run.` Trailer-bearing commits, and commits touching **other** paths, do not trip it — proceed. |
| Phase-2 TOCTOU re-check   | **MUST, not MAY.** The gate opens an authoring-length window in which the branch can move, and phase 2 is the **only** layer that writes: an optional re-check that an implementer skips would check out at the remote head and write straight over the out-of-pipeline edit the step-5 guard exists to protect, with no STOP. If a re-check STOPs, phase 2 **MUST preserve the confirmed content** — write it to the session temp dir (`scripts/tmp-dir.sh`) and **surface the path in the STOP** — never discard it. A guard that destroys the founder's page while protecting someone else's commit has traded one loss for another. Preservation is what makes a mandatory STOP here costless.                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Control-flow tail         | Mirror `docs-pipeline-core.md` §7 / `docs-pipeline-release.md` §13 / `refs/adr-pipeline.md`'s §3a: after the PR is raised, drive the review loop to convergence via `/loop /sdlc:loop <PR_URL>` (falling back to `ScheduleWakeup` if the harness cannot nest `/loop`). If the run ended **before** any PR (manifest-absent silent no-op, deactivated-type report, founder-declined-at-gate, a usage STOP, a page-exists STOP, or a precondition/guard STOP), release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — only the manifest-absent path is silent. (`seed adr` branches to the ADR pipeline before reaching this generic seed control flow at all — see `commands/docs.md` step 7 — so its own exit paths are not enumerated here.)                                                                                                                                                                                                                                                                                                                                                              |

### Where edits live, and what a re-run does to them

| Edit made…                                                                                 | Committed by                                                  | A re-run…                                                                                                                                                                                                                                                         |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **At the founder-confirm gate** (the founder authors/edits the scaffold before confirming) | phase 2, carrying the `Seed-Generated: <type>/<SLUG>` trailer | **Re-presents a fresh scaffold.** Phase 1 re-scaffolds from the template + topic every run — a prior run's authored prose is **not** carried forward. Not silent (the founder sees exactly what will be written before confirming), but **not preserved either**. |
| **On the branch, outside the pipeline** (a `/sdlc:loop` review-fix commit, a direct push)  | anything **without** the trailer                              | **STOPs — at §16 step 5, before the founder authors.** The re-run content guard refuses to overwrite it and hands the decision back.                                                                                                                              |

The distinction is the **trailer, not the commit subject**. Keying on the subject would be wrong:
phase 2 commits founder gate edits under the normal `docs(docs): seed <type> <SLUG>` subject, so a
subject test classifies them as pipeline-authored and the guard never fires — correct for gate edits
(re-scaffolded by design), but it must not be mistaken for _preserving_ them.

For `seed`, the gate-edit row bites harder than for `release`: a release gate edit is a tweak to
machine-aggregated content, whereas **a seed gate edit is the entire page**. Re-running a seed whose
PR is open therefore means re-authoring. A real UX cost, accepted for v1.

## 19. Seed mode — no-op / change-gate + re-run semantics

### Content purity — the seed variant of the `gh` boundary

`docs-pipeline-release.md` §11 established that content written to a file must be a pure function of repo state — `gh`
enrichment feeding written content made output depend on ambient network state and broke idempotence.
**That rule's rationale does not transfer to `seed`, so its form must not be copied blindly.** The
seed rule is:

> **The written page is exactly what the founder confirmed at the gate, byte for byte — never
> re-derived, re-enriched, or re-drafted at write time.**

The founder-confirm gate **is** the purity boundary.

**Scope this rule to content derivation — it is NOT a prohibition on phase 2 touching the network.**
Phase 2 consults no corpus, no `gh`, and no network **for any byte of the page**: it receives the
confirmed content and writes it unchanged. It self-evidently **does** perform the mechanical
git/`gh` operations the write itself requires — `git fetch origin`, `git push`, `gh pr create`, and
the PR number a guard STOP must quote — **because raising the PR is AC4**. An absolute reading
("phase 2 consults no network") would forbid those and silently fail the very AC the phase exists to
satisfy.

This scoping is why `seed` can safely let phase 1 consult ambient sources that `release` must not:

- `refs/doc-types.md` gives `concept` the `source-of-truth` **`learnings corpus`**, and `how-to` /
  `integration-guide` **`founder-authored draft + learnings corpus`** — so phase 1 **may** query
  claude-mem for corpus material to enrich the scaffold for those three types. (`tutorial`'s
  `source-of-truth` is **`founder-authored`** only — **no corpus consultation for it.**)
- `gh` may likewise enrich what is **displayed**.

Both are safe **because** `seed` makes no byte-identity claim (below) and because everything they
touch is a _draft a human reads and rewrites_ before any byte is written. A corpus hit that differs
between runs changes what the founder is _offered_, never what is _written_ behind their back. Were
`seed` ever to gain a "re-derive on re-run" path, this reasoning would have to be re-derived with it
— it is contingent on the gate, not on the sources being trustworthy.

### claude-mem availability — never a halt for `seed`

If the claude-mem MCP tools are unavailable, phase 1 **proceeds without corpus enrichment and says
so at the gate. It does NOT halt.** A deliberate divergence from `distill`, which
`refs/adr-pipeline.md` §5 already draws: _"claude-mem tools absent in distill mode → halt distill …
use seed adr."_ The reason is structural: `distill`'s entire input **is** the corpus, so
without it there is nothing to distill; `seed`'s input is the **founder**, and the corpus is
enrichment. Halting would block a founder from authoring a page they can write unaided.

### Deterministic index + `llms.txt` regen (AC4)

After the confirmed page write, phase 2 deterministically regenerates the doc index and `llms.txt` —
the un-gated half of the run (the same "auto rows are un-gated" discipline `sync` and `release`
apply):

- **`llms.txt`** — **only if the `llms-txt` row is present and enabled in the manifest, checked
  independently of `SEED_ROW`.** `llms-txt` is a `sync`-triggered row; it is **not** the row `seed`
  was invoked for, so its state is **never** inferred from `SEED_ROW`'s activation — a founder may
  perfectly well have `concept` enabled and `llms-txt` declined. Absence is never inferred as enabled:
  a founder who declined `llms-txt` at `/init` (row absent) must never have it written or overwritten
  by a `seed` run. If **disabled or absent**, phase 2 does not write or touch `llms.txt` at all this
  run — any existing file is left exactly as-is. When it **is** enabled: reuse `docs-pipeline-core.md` §8's algorithm
  verbatim — index-only, grouping the generated pages of every enabled `public: yes` row by Diátaxis
  quadrant, each entry a `title — one-line description — relative link` derived from page
  frontmatter. The newly seeded page appears in it. Idempotent; committed only if changed.

- **Frontmatter-MISSING-OR-UNFILLED pages the regen encounters are SKIPPED, never fatal, and never
  fabricated.** This story mandates frontmatter on the **page it writes**, and `docs-pipeline-core.md` §8's algorithm reads
  frontmatter from **every** enabled `public: yes` page in the tree. As of NA-61 the `writing-docs`
  templates emit `title`/`description`, so a page authored from a current template carries the
  **keys** — **but the regen cannot tell a template-produced page from a legacy one at regen time**
  (there is no origin marker, and an age heuristic would be forbidden ambient input), and it also
  cannot assume the founder-confirm gate (§16 step 7) ran on every page it walks — a page committed
  by some other path, or predating that gate's `TODO(fill)` check, may still carry the scaffold's
  unfilled sentinel untouched. So the trigger for this skip is **"missing `title`/`description` OR
  either still carries the `TODO(fill)` sentinel"** — not presence alone. It stays **universal**; it
  simply fires **rarely** now — only for a legacy/hand-authored page (or one predating NA-61) that
  lacks frontmatter, or an unedited scaffold that slipped past the gate. Do not remove it: legacy
  pages still depend on it. That exposure is pre-existing and shared with `sync`/`release`; `seed`
  merely walks into it.
  - A page missing, or still carrying the `TODO(fill)` sentinel in, `title`/`description` is
    **omitted from `llms.txt`** and its path **surfaced in the phase-2 output and the PR body**.
    Loud, not silent — this is the invariant the seed founder-confirm gate's own `TODO(fill)` check
    (§17) exists to make rare, not the invariant that makes that gate check optional: the gate is the
    fast, in-context catch; this skip is the regen-time backstop for anything that reaches it anyway.
  - It is **never a STOP.** A STOP mid-phase-2 would **tear the write** — the founder's page
    committed, the index not — and would let an unrelated page's defect block a valid seed the
    founder just authored.
  - Its `title`/`description` are **never** inferred from the body or filename, and an unfilled
    sentinel is **never** silently treated as "present enough" to ship. Both would fabricate or leak
    unintended text into published index copy, the fabrication boundary this pipeline holds
    everywhere else.

- **The doc index** — if the consumer's docs tree already carries a section index page at
  `SEED_ROW`'s `target-path`, regenerate it deterministically (**upsert** the page's entry — add if
  absent, rewrite in place if present; never append a duplicate). If none exists, `llms.txt` is the
  sole index and **no separate section index is created**. No new index file type is invented.

  **The "already carries a section index" test is evaluated against the PRE-write tree state** — the
  branch/base head as fetched — **never the post-write working tree.** Otherwise a page this run just
  wrote can satisfy the regen's own precondition and be rewritten as a generated index inside the
  same commit: exactly the `seed <type> index` self-destruction §15's reserved-page-id STOP closes
  from the other side. **Both rules are required; neither is redundant.**

- **All four seed types are `public: yes`** in the registry, so a seeded page always belongs in
  `llms.txt` when that row is enabled. (`adr` is the registry's only `public: no` row — handled by
  the special `seed adr` route to `refs/adr-pipeline.md`, not the generic seed machinery.)

### No-op / change-gate semantics

- **Manifest-absent silent no-op (AC5).** See
  [`docs-pipeline-core.md` §1's Manifest gate](docs-pipeline-core.md#manifest-gate-shared-by-sync-release-seed-and-audit) — the base-ref pre-check is
  ordered **before** the absence conclusion. No prompt, no branch, no dispatch, no PR, no error, **no
  stdout**, exit 0.
- **Deactivated type → informational report, no write (AC2)** (§16 step 3). Distinct from the silent
  no-op: the manifest exists, so the founder opted in.
- **Founder rejects at the gate → nothing written**, no branch, no PR, no phase-2 dispatch; report
  and exit cleanly. There is no deterministic half worth committing: the index/`llms.txt` regen is a
  _consequence_ of the page write, so with no page there is nothing to reindex.
- **Commit/PR only on actual content change (AC4).** Phase 2 commits only if `git status --porcelain`
  on the written paths is non-empty.
- **`llms.txt` regenerated only when its own manifest row is present and enabled**, committed only if
  changed.

### Re-run semantics — what is and is not deterministic

**`seed` makes NO byte-identity claim for a seeded page body, and this ref will not imply one.**
`docs-pipeline-release.md` §14's idempotence contract ("same range + same confirmed content → same bytes") is a statement about
a **generator** whose input is repo state. `seed`'s page body has no such input: it is founder prose
typed at a gate. Re-running `seed concept offline-sync` re-prompts and re-authors; asserting
byte-identity would be false. **Do not copy `docs-pipeline-release.md` §14's idempotence wording.**

| Property                                        | Holds?  | Scope / why                                                                                                                                                        |
| ----------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Page **identity** is stable across re-runs      | **Yes** | `SLUG` normalisation — one branch, one PR, one page id per topic, regardless of how the topic was typed                                                            |
| Page **body** is byte-identical across re-runs  | **No**  | It is founder-authored input, re-authored at each run's gate. No claim is made                                                                                     |
| **Write-time fidelity**                         | **Yes** | Phase 2 writes the confirmed content **verbatim** — the bytes written are the bytes the founder saw. **This, not byte-identity, is `seed`'s content guarantee**    |
| **`llms.txt` / index regen** is deterministic   | **Yes** | Pure function of the enabled `public: yes` rows' page frontmatter (`docs-pipeline-core.md` §8). Re-running over an unchanged page set yields byte-identical output |
| **Commit/PR only on actual content change**     | **Yes** | Phase 2 commits only if `git status --porcelain` on the written paths is non-empty                                                                                 |
| Branch commits are **preserved** across re-runs | **Yes** | Never reset, never force-pushed — §18                                                                                                                              |
