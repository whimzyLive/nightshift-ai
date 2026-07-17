# Docs pipeline

Shared resolve → diff → regen → draft → founder-confirm → write → commit/PR protocol for
`/sdlc:docs sync` (§§2–8), `/sdlc:docs release` (§§10–14), and `/sdlc:docs seed` (§§15–19),
referenced by both `agents/knowledge-engineer.md` and `commands/docs.md` so the
contract lives in exactly one place. Neither file re-inlines this logic — both summarize and link
back here. Mirrors `refs/adr-pipeline.md`'s shape (copy the skeleton; do not abstract a shared ref
between the two — same "copy the shape, do not generalize" rule `doc-types.md` and Epic NA-50 both
state).

## 1. Purpose + ownership note

This is the single-source pipeline for `/sdlc:docs`. All writes land under paths resolved from the
consumer repo's `.claude/project/docs-manifest.md` (row `target-path`s) and, where the manifest is
silent, `.claude/project/project-context.md`. In this SDLC repo itself, a plugin-authoring write
(touching `plugins/**`) stays within the `ai-enablement-engineer` write-scope — see the Active-guard
scope note in the agent's First steps.

### Manifest gate (shared by sync, release, and seed)

Both modes apply this identical gate at the **command layer**, before any dispatch — defined once
here; `commands/docs.md` points at it rather than re-deriving it. Resolve
`.claude/project/docs-manifest.md` **checkout-independently** — never the working tree, so a stale
local checkout never skews which rows are active — but only **after** the base ref itself is
confirmed to resolve. A bare `git show origin/<BASE-BRANCH>:<path>` failure is otherwise ambiguous
between two very different causes: the path genuinely doesn't exist at that ref (manifest absent —
the intended silent no-op), or the **ref itself** doesn't resolve (a fresh/shallow CI clone that
hasn't fetched `<BASE-BRANCH>` yet, or `<BASE-BRANCH>` renamed/deleted on `origin`) — the latter
must **STOP**, never silently read as absent, or a fully opted-in repo carrying a real manifest gets
a silent no-op that reports success while generating nothing.

```bash
git fetch origin --quiet || STOP "git fetch failed"
git rev-parse --verify --quiet "origin/<BASE-BRANCH>^{commit}" >/dev/null \
  || STOP "cannot resolve origin/<BASE-BRANCH>"

git show "origin/<BASE-BRANCH>:.claude/project/docs-manifest.md" >/dev/null 2>&1
```

- **`git show` succeeds** → the manifest exists; proceed into the invoking mode's own steps.
- **`git show` fails** → now unambiguous, because the ref above already resolved — the failure means
  the **path** doesn't exist at that (known-good) ref, i.e. genuine manifest absence → **silent
  no-op**: no branch, no dispatch, no PR, no error, **no stdout**, exit 0 (AC5 for `sync`, AC6 for
  `release`). This is the zero-setup-cost guarantee for repos that declined the `/init` docs opt-in,
  deliberately distinct from a usage STOP (which does print a message). Do not dispatch
  `knowledge-engineer` in this case.

## 2. Two-phase dispatch (split across the confirmation boundary)

A dispatched subagent runs to completion and returns — it cannot pause for interactive human
input. So the founder-confirmation gate cannot live inside the `knowledge-engineer` dispatch; it
lives at the **command layer**, between two separate dispatches of the same agent. This is the
same split `refs/adr-pipeline.md` §2 and `/sdlc:analyze`'s scan-then-apply flow use.

**Phase 1 — compute & draft, writes nothing:**

1. Resolve `.claude/project/docs-manifest.md`. (The command layer already gated on its presence
   before dispatching — see §6 — so phase 1 always has a manifest to read.)
2. Resolve `STORY_BRANCH` — `git fetch origin --quiet`, then `origin/feat/<STORY-KEY>` preferred,
   `origin/fix/<STORY-KEY>` fallback. (The command layer already resolved this before dispatching —
   see §7 — so phase 1 receives `STORY_BRANCH` as an input, it does not re-resolve it.)
3. Compute `CHANGED_FILES` (`git diff --name-only "origin/<BASE-BRANCH>...$STORY_BRANCH"`) and
   `CHANGED_DIFF` (`git diff "origin/<BASE-BRANCH>...$STORY_BRANCH"`) — both from the same
   three-dot range, against the **remote-tracking** base ref (see §7) — never the bare local
   `<BASE-BRANCH>`, whose local checkout may be stale relative to `origin`.
4. Resolve affected rows against the [source-of-truth map](#3-deterministic-regen-algorithm) — for
   each **enabled** manifest row whose registry `trigger` contains `sync`, determine whether it is
   affected per its keying kind (path / content / always).
5. For each affected `auto` row, produce the deterministic regen content (see §3). `llms-txt`
   regenerates every run (AC4).
6. For each affected `how-to` row, draft a refresh of the how-to page(s) whose `source:`
   frontmatter intersects `CHANGED_FILES` (see §5), using the `writing-docs` skill.
7. Return to the command layer: the deterministic regen summary + content, the `llms.txt` content,
   and the narrative how-to drafts. **Nothing is written to disk in phase 1.**

**Founder-confirmation gate (command layer, NOT the agent — see §2's opening paragraph and
`commands/docs.md`).**

- Present the deterministic regen summary (informational — auto rows are not gated) and each
  narrative how-to draft (gated). The founder may accept/edit/reject each narrative draft.
- The gate is **skipped** when there are zero narrative drafts — the run proceeds straight to
  phase 2.

**Phase 2 — write confirmed, fresh dispatch:**

Phase 2 is a fresh subagent dispatch with no visibility into phase 1's return or the gate that ran
in between — the command MUST pass it the deterministic content **and** the founder-confirmed
narrative drafts **verbatim** (including any founder edits), inline in the dispatch prompt or via
session temp-dir files passed by path (per `${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh`, the same
pattern `refs/adr-pipeline.md` §2 uses). Phase 2 writes what the founder saw; it never re-drafts.

8. Check out a branch cut from the **story branch head** (`$STORY_BRANCH`, not `<BASE-BRANCH>` —
   see §7) — the tree must contain the changed source the regen read.
9. Write the deterministic regen content, the regenerated `llms.txt`, and the founder-confirmed
   narrative drafts, each under its manifest-resolved `target-path`.
10. If `git status --porcelain` on the written target paths is **empty** (deterministic output was
    byte-identical to what's already committed, and no narrative draft was confirmed) → no commit,
    no PR, exit cleanly (AC6). Otherwise commit via `conventional-commit`, push, and open or update
    the sync PR (see §7).

## 3. Deterministic regen algorithm

For each **enabled** manifest row whose registry `trigger` contains `sync`, look up its registry
row in `refs/doc-types.md` and resolve whether it is **affected** this run per the source-of-truth
map below. The **keying** column states whether a row is matched against the name-only
`CHANGED_FILES` list, against hunks in the unified `CHANGED_DIFF`, or is always affected:

| Doc-type            | `generation-mode` | Keying  | Affected when…                                                                                                       |
| ------------------- | ----------------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| `command-reference` | auto              | path    | `CHANGED_FILES` contains any `commands/**` file                                                                      |
| `agent-reference`   | auto              | path    | `CHANGED_FILES` contains any `agents/**` file                                                                        |
| `skill-reference`   | auto              | path    | `CHANGED_FILES` contains any `**/SKILL.md`                                                                           |
| `config-reference`  | auto              | path    | `CHANGED_FILES` contains `.claude/project/project-context.md` or a config template under `refs/*-template.md`        |
| `hooks-contract`    | auto              | content | a name-matched `.claude/settings*.json` or referenced hook script has hunks in `CHANGED_DIFF` touching a hooks block |
| `error-reference`   | auto              | content | a name-matched command/agent/ref file has hunks in `CHANGED_DIFF` touching an "Error Handling" / error-table section |
| `llms-txt`          | auto              | always  | **every run** (AC4)                                                                                                  |
| `how-to`            | draft-for-review  | path    | `CHANGED_FILES` intersects an existing how-to page's `source:` frontmatter glob-list (see §5)                        |

For each affected row, regenerate its reference-doc set **deterministically** into the row's
manifest `target-path` — this is a prose algorithm executed inline by the dispatched agent, not a
committed script (matches the ADR index-regen algorithm in `refs/adr-pipeline.md` §10 and the
plugin's "instructions not code" style). **Idempotent**: re-running with no source change yields
byte-identical output.

1. **`command-reference`** — for each `commands/**` file, parse its frontmatter (`description`)
   and body; emit one reference page per command, structured identically (one entry per
   symbol/command, consistent shape), under `target-path`.
2. **`agent-reference`** — same, one page per `agents/**` file.
3. **`skill-reference`** — same, one page per `**/SKILL.md`'s frontmatter (`name`, `description`).
4. **`config-reference`** — parse `.claude/project/project-context.md` plus any `refs/*-template.md`
   config templates; emit a single reference page enumerating the config surface.
5. **`hooks-contract`** — parse the hooks block of `.claude/settings*.json` plus any referenced hook
   script; emit a single reference page describing the hook contract (trigger, matcher, command).
6. **`error-reference`** — aggregate every "Error Handling" / error-table section across
   commands/agents/refs into one reference page, one entry per scenario/behaviour row.
7. **`llms-txt`** — see §8's format; regenerated every run regardless of whether any other row was
   affected (AC4).
8. **`how-to`** — NOT part of this deterministic step; affected how-to pages are drafted (not
   auto-written) per §5/§2 step 6, and only written after founder confirmation.

Regeneration for each `auto` row overwrites only the pages derived from files it found affected —
it never touches an unaffected row's pages, and it never touches `how-to` pages (draft-for-review,
gated).

## 4. Voice/format resolution

Narrative drafting (the `how-to` refresh drafts) resolves voice and output format via
`writing-docs`'s chain, never hardcoded: `.claude/project/docs-manifest.md` "Voice & format"
section → `.claude/project/project-context.md` → a stated plain-Markdown, neutral-voice default
when neither is present or silent on a point. See `plugins/sdlc/skills/writing-docs/SKILL.md`
"Voice, Craft, and Output Format" for the full resolution rule and the craft rules that apply
regardless of which source resolves it.

## 5. `source:` refresh convention

Restated here verbatim (normative source: `docs/superpowers/specs/NA-52.md` "`source:` frontmatter
convention") so pipeline readers see it alongside the drafting flow, and so it is not duplicated
inconsistently between this ref and the how-to template it governs:

- **Key name:** `source` (a top-level YAML frontmatter key on a how-to page).
- **Value:** a YAML list of repo-root-relative **glob** strings identifying the source files whose
  change should trigger a refresh draft of this page.
- **Match semantics:** a how-to page is **affected** iff at least one entry in its `source:` list
  matches at least one path in `CHANGED_FILES` under standard glob semantics (`*` within a path
  segment, `**` across segments). Matching is against the name-only changed-file set — it is a
  path-keyed row (see §3's table).
- **Absent key:** a how-to page with **no** `source:` frontmatter is **never** auto-refreshed by
  `sync`. This is the deliberate opt-in boundary — authoring/opting a page in is a founder action
  (add `source:`), not something `sync` infers.
- The template that emits this key at authoring time lives in
  `plugins/sdlc/skills/writing-docs/SKILL.md`'s how-to structure template — see that file for the
  exact emitted shape (a one-line inline comment plus the `source:` glob list).

## 6. No-op / change-gate semantics

- **Manifest-absent silent no-op (AC5).** See [§1's Manifest gate](#manifest-gate-shared-by-sync-release-and-seed)
  — the command layer never dispatches `knowledge-engineer` when that gate finds the manifest
  genuinely absent, distinct from the STOP the same gate raises first if `origin/<BASE-BRANCH>`
  itself won't resolve. Not something phase 1 checks — phase 1 is never invoked in this case.
- **Story-branch-missing WARNING, never a silent success.** If neither `origin/feat/<STORY-KEY>`
  nor `origin/fix/<STORY-KEY>` exists, the command layer emits the explicit WARNING (see
  `commands/docs.md`) and exits — never a silent clean exit that could read as "docs already
  current." v1 sync is branch-diff-only; post-merge sync is deferred to NA-55.
- **Commit/PR only on actual content change (AC6).** Phase 2 step 10 (§2) is the single point that
  decides this: an empty `git status --porcelain` on the written target paths means no commit, no
  PR — a clean, deterministic re-run is a no-op by construction.
- **`llms.txt` regenerated every run, committed only if changed (AC4 + AC6).** `llms-txt` is always
  affected (§3's table), so its content is always recomputed — but §2 step 10's change-gate still
  applies: if the recomputed content is byte-identical to what's committed, it contributes nothing
  to the `git status --porcelain` diff and is not part of the commit.

## 7. Branch / PR naming + control flow

| Item              | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Branch            | `docs/sync-<STORY-KEY>`, cut from the **story branch head** (`origin/feat/<STORY-KEY>`, fallback `origin/fix/<STORY-KEY>`) — **not** `<BASE-BRANCH>`. The story branch carries the changed source the deterministic regen must read; branching off base would regenerate from a tree missing those changes.                                                                                                                                                                                                                    |
| Commit            | `docs(docs): sync <STORY-KEY> reference docs` (via `conventional-commit`)                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| PR title          | `docs(docs): sync <STORY-KEY>`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| PR base           | `<BASE-BRANCH>` from project-context (never assume `main`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Diff source (v1)  | `CHANGED_FILES=$(git diff --name-only "origin/<BASE-BRANCH>...$STORY_BRANCH")` and `CHANGED_DIFF=$(git diff "origin/<BASE-BRANCH>...$STORY_BRANCH")`, both from the same `origin/<BASE-BRANCH>...$STORY_BRANCH` three-dot range, against the **remote-tracking** base ref (checkout-independent — a stale local base never skews the diff), after `git fetch origin --quiet`. Dual diff-source selection (story-branch-vs-develop **vs** merged-commit) is out of scope — deferred to NA-55.                                   |
| First-run PR      | Create the branch, commit, push, open the PR (`gh pr create`) against `<BASE-BRANCH>`.                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Re-run behaviour  | **Open or update** (AC6): before creating, check whether `docs/sync-<STORY-KEY>` already exists on `origin` (`git rev-parse --verify origin/docs/sync-<STORY-KEY>` / `gh pr list --head docs/sync-<STORY-KEY>`). If it does → check it out, **`git reset --hard` onto the freshly regenerated state** (the branch content is fully derived, so a hard reset is safe and keeps history clean), then **`git push --force-with-lease`** to update the existing open PR — never open a duplicate PR.                               |
| Control-flow tail | Mirror `commands/adr.md`: after the PR is raised, drive the review loop to convergence via `/loop /sdlc:loop <PR_URL>` (falling back to `ScheduleWakeup` if the harness cannot nest `/loop`). If the run ended **before** any PR, release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — this covers the manifest-absent silent no-op, the story-branch-missing WARNING, a usage STOP, and a clean "nothing changed" no-op alike (all four release without a PR; only the manifest-absent path is silent). |

## 8. llms.txt format (v1 decision)

`llms-txt` regenerates at the `llms-txt` row's manifest `target-path` (registry default `llms.txt`,
repo-root) deterministically on every run: an **index-only** file (no full-content `llms-full.txt`
in v1), grouping the generated pages of every enabled, `public: yes` manifest row by Diátaxis
quadrant, each entry a `title — one-line description — relative link` line derived from the
generated page's frontmatter. Idempotent, no narrative synthesis. This matches the `llms-txt` row's
`source-of-truth` cell in `refs/doc-types.md` — see that cell for the authoritative wording rather
than restating it here; `refs/doc-types.md`'s own Registry self-check section is what keeps that
cell's wording singular within that file.

## 9. Cross-reference

The registry (`refs/doc-types.md`) and the manifest template (`refs/docs-manifest-template.md`)
are read, not owned, by this pipeline — `sync` never edits either. The `writing-docs` skill
(`plugins/sdlc/skills/writing-docs/SKILL.md`) owns the how-to structure template (including the
`source:` frontmatter emission, §5 above) and the voice/format resolution chain (§4 above) — this
ref restates the pieces `sync` depends on but does not re-inline the full skill.

## 10. Release mode — merged-story enumeration

Release aggregates work **already merged to base**, so the diff source is `origin/<BASE-BRANCH>` —
never a story branch (contrast §7, where `sync` cuts from the story branch head).

Every git failure here is a **STOP**, never a silent fallthrough into the "no tags yet" branch.
Discriminating the two needs **positive pre-checks**, not stderr matching alone: git exits `128`
for both "no tags exist" and unrelated fatals, and a **shallow clone with no reachable tags emits
the identical `fatal: No names found` text** as a genuine first release. Stderr therefore cannot
separate them; the shallow pre-check is what makes the fallthrough safe.

```bash
git fetch origin --tags --quiet || STOP "git fetch failed"

# The base ref must resolve BEFORE any describe — an unresolvable base is a STOP,
# never a "no tags yet" first-release run.
git rev-parse --verify --quiet "origin/<BASE-BRANCH>^{commit}" >/dev/null \
  || STOP "cannot resolve origin/<BASE-BRANCH>"

# POSITIVE shallow pre-check. A shallow clone can hide every tag and still fail describe
# with the identical "No names found" text, so it MUST be excluded before that text is trusted.
[ "$(git rev-parse --is-shallow-repository)" = "false" ] \
  || STOP "shallow clone — cannot enumerate the release range (run: git fetch --unshallow)"

# Session-scoped temp dir (./.tmp/<key>), removed by scripts/cleanup-tmp.sh /
# session-complete.sh on every exit path incl. STOP — never a bare, un-trapped mktemp.
TMP="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh")"
DESCRIBE_ERR="$TMP/describe.err"

if LAST_TAG=$(git describe --tags --abbrev=0 "origin/<BASE-BRANCH>" 2>"$DESCRIBE_ERR"); then
  RANGE="$LAST_TAG..origin/<BASE-BRANCH>"        # tagged: exclusive of the tag, inclusive of head
elif grep -q 'No names found' "$DESCRIBE_ERR"; then
  LAST_TAG=""                                    # genuine "no tags yet" — first-ever release
  RANGE="origin/<BASE-BRANCH>"                   # SINGLE-ENDED: full history to head, root inclusive
else
  STOP "git describe failed: $(cat "$DESCRIBE_ERR")"
fi
```

- **Only `No names found` falls through**, and only _after_ the shallow pre-check passed. Do **not**
  also match `No tags can describe` — that text belongs to `--contains` / no-`--tags` invocations and
  cannot be emitted by `git describe --tags --abbrev=0`; matching it would be a dead alternate
  implying a discrimination this code does not perform.
- **No tags (first-ever release)** → the range is the **single-ended** `origin/<BASE-BRANCH>`.
  Deliberately **not** `"..origin/<BASE-BRANCH>"` (git defaults the omitted left side to `HEAD`,
  which on an up-to-date base checkout yields an **empty** range → a "no stories merged" no-op → the
  first-ever release silently shipping nothing while reporting success). Deliberately **not**
  `<root-sha>..origin/<BASE-BRANCH>` either — that form **excludes** the root commit. The
  single-ended form is the only one that is both non-empty and root-inclusive.

### Enumeration format (delimited, machine-parseable)

```bash
# US (0x1f) separates fields; RS (0x1e) terminates each commit record.
# git does NOT forbid these bytes in a commit message — it stores and replays them verbatim —
# so this format is chosen because they are vanishingly rare in practice, not because they are
# impossible. A message containing a literal RS/US will mis-split; accepted for v1 because the
# failure is loud and local (a garbage key/summary surfaces at the founder-confirm gate, where a
# human is already reading), not silent corruption of a written byte.
git log "$RANGE" --format='%s%x1f%b%x1e'
```

**Why not `--format='%s%n%b'`.** That format emits **no record separator and no field separator**,
and bodies are multi-line — so there is no way to tell where one commit's body ends and the next
commit's subject begins. Every downstream rule that says "the commit that carried the key", "the
subject", "the body", or "the most recent commit" is then underivable. The delimited format above is
what makes those rules implementable; **do not simplify it back.**

**Parsing.** Split on RS (0x1e) into records. Two mechanical rules are required, because `git log`
emits a newline after each record terminator:

1. **Strip one leading `\n`** from each record (every record after the first carries it).
2. **Drop the final element** — the newline after the last RS leaves a trailing whitespace-only
   element that is not a commit.

Then split each surviving record on US (0x1f) into `(subject, body)`. A record that does not yield
exactly 2 fields is malformed — surface it and STOP rather than guessing at field boundaries.

### Story-key extraction

For each record, extract Jira story keys from **subject and body**, then take the de-duplicated
union across records. Each key retains the `(subject, body)` of the record(s) that carried it.

**Scope the regex to the consumer's Jira project key(s) — a set, not a single key.** Resolve
`PROJECT_KEYS`:

1. The **primary** key: `.claude/project/project-context.md`'s "Jira project key".
2. Any **additional** keys: `.claude/project/docs-manifest.md`'s optional "Additional Jira project
   keys" field (see `refs/docs-manifest-template.md`) — a comma-separated list of legacy or
   secondary project keys whose commits should also be recognised (e.g. a repo migrated from an old
   Jira project key to a new one still carries old-key references in its history that must not be
   silently dropped from the changelog).

`PROJECT_KEYS` is the union of both. Build the regex as an alternation over the set, still anchored
so it cannot degrade into the unscoped form:

```text
\b(?:KEY1|KEY2|...)-[0-9]+\b
```

**Why a set, not one key.** An earlier version of this rule scoped to a single primary key. That
closes the false-positive defect below, but **regresses on any multi-project repo**: a repo whose
history carries both a current key (e.g. `NA-*`) and a legacy key from before a Jira project rename
(e.g. `ET-*`) would silently drop every commit whose only key is the legacy one from the merged-story
set — the founder-confirm gate then presents a changelog that omits shipped stories, and the PR
merges it, with nothing surfacing the gap. This repo is itself such a case (its own history carries
both `NA-*` and `ET-*` keys). A key **set** — primary plus any additional keys the founder configures
— fixes this without reopening the false-positive hole, because every key in the set is still an
exact, configured literal, never a generic pattern.

A bare `[A-Z][A-Z0-9]*-[0-9]+` (matching **any** uppercase-alnum-dash-digits token, not a configured
key) is **too loose** and false-positives on ordinary prose — `UTF-8`, `RFC-2119`, `SHA-1`,
`ISO-8601`, and `AES-256` all match it, each of which would emit a bogus `UTF-8 — <summary>`
changelog line. If `PROJECT_KEYS` is empty (project-context carries no Jira project key and the
manifest lists no additional keys), fall back to the loose regex and note the risk in the gate
output — never silently emit unfiltered matches. If `PROJECT_KEYS` is non-empty, always use the
alternation above — even when it resolves to a single key — never the loose regex.

**"Most recent" is well-defined:** `git log` emits newest-first by default, so for a key appearing in
several records, the **first** record encountered is its most recent commit. Do not add `--reverse`
without also inverting that rule.

`gh` is **not** consulted for any content that lands in a file — see §11's `gh` boundary.

## 11. Release mode — changelog aggregation + upsert

### Aggregation inputs (repo-derived, no network)

Change type and summary both come from the `(subject, body)` records §10 already parsed — the
**subject** for type and summary, the **body** for the breaking-change footer. No additional git
call and **no network call** is needed.

| Need        | Repo-derived source (always available)                                                                                                                                                                                                                                                                                                                                                                           |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Change type | The **subject's** conventional-commit `type`: `feat` → **Added**; `fix` → **Fixed**; any other recognised type (`refactor`/`perf`/`docs`/`chore`/…) → **Changed**. Promoted to **Breaking** by a `!` marker in the subject (`feat!:`) **or** a line-anchored `BREAKING CHANGE:` footer in the body. A subject with **no** parseable prefix → **Changed** (the neutral bucket — never dropped, never guessed at). |
| Summary     | The **subject's** description text — the remainder after `type(scope):` — used verbatim, trimmed.                                                                                                                                                                                                                                                                                                                |

- **The `BREAKING CHANGE:` test is line-anchored, never a substring search.** Per Conventional
  Commits it is a **footer**: the token must begin a line — match `^BREAKING[ -]CHANGE:` (multiline)
  against the body. A body that merely _mentions_ the string in prose is **not** a breaking change.
  This is a live hazard, not a hypothetical: this repo's own history contains commit messages
  discussing `BREAKING CHANGE:` in prose, and a naive `"BREAKING CHANGE:" in body` test flags them.
- **The `gh` boundary: `gh` never contributes to written content.** `gh` MAY enrich what is
  **displayed** to the founder at the confirm gate (e.g. PR titles alongside keys); it MUST NOT feed
  any byte written to a file. Letting a `gh` lookup supply the summary would make file content depend
  on **ambient network state**: run 1 with `gh` up writes PR titles, run 2 rate-limited rewrites the
  same release with commit subjects → a non-empty `git status --porcelain` → a spurious commit that
  _degrades_ a changelog already under review, contradicting §14's idempotence contract. Written
  content is a pure function of the commit range.
- **A key appearing in multiple records** takes the highest-precedence change type among them
  (**Breaking > Added > Fixed > Changed**) and the subject of its **most recent** record as the
  summary (the first record encountered — `git log` is newest-first).
- **Deterministic ordering** (required for the byte-identical guarantee): emit sections in the fixed
  order **Breaking → Added → Changed → Fixed**, omitting empty sections. Within a section, sort story
  lines by key — project prefix lexicographically, then the numeric suffix **numerically** (so
  `NA-9` precedes `NA-53`, which a plain string sort gets wrong). Line shape: `<KEY> — <summary>`.
- **Each change-type bucket is a `###` sub-heading** (`### Breaking`, `### Added`, `### Changed`,
  `### Fixed`) — one level below the `## <VERSION>` section heading, never `## `. This is
  load-bearing for the upsert boundary below: that boundary terminates at the next `## ` heading, so
  a bucket pinned at `## ` instead of `### ` would prematurely end the section at its own first
  bucket — the upsert would then insert each re-run's fresh content **above** the stale remainder
  instead of replacing it, the changelog would accumulate duplicate `### Added`/`### Fixed` blocks
  under one `## <VERSION>`, and `git status --porcelain` would be non-empty on every re-run even
  with no new merged stories — breaking §14's "re-run with no new stories commits nothing" claim.
- **Never fabricate.** The changelog emits exactly what the commits support — no inferred prose, no
  invented summaries. A bare-key line is never emitted, because the fallbacks above always resolve
  both fields.

### Changelog file shape

The `changelog` row's `target-path` (registry default `docs/changelog/`) holds a **single cumulative
file**, `index.md` (Keep-a-Changelog style, newest-first). If it does not exist, phase 2 creates it
with this preamble — **including frontmatter**, per §12's "every written release page MUST carry
`title` + `description`" rule, which applies to this page too — then applies the upsert below:

```markdown
---
title: Changelog
description: All notable changes to this project, generated by /sdlc:docs release.
---

# Changelog

All notable changes to this project are documented in this file. Generated by
`/sdlc:docs release <version>`; each release upserts its own `## <VERSION>` section.
```

Omitting the frontmatter here would silently break §14's `llms.txt` regen, which derives every
entry's `title`/`description` from page frontmatter: since this preamble is written **once** and
never revisited (the upsert boundary below explicitly never touches it), a missing frontmatter
block would either drop the changelog from `llms.txt` forever, or make the regen STOP on a page it
expects to carry frontmatter — after the founder has already confirmed the release content.

### Upsert rule

Maintained by **upsert**, not unconditional prepend. A prepend-only rule contradicts §14, because
`release` creates no tags, so a re-run of a version whose PR already merged would find its
`## <VERSION>` section present and prepend a **second** one.

1. **Scan** the cumulative file for an existing `## <VERSION>` heading (exact match on the
   **normalised** `VERSION` — which is what makes `## 1.4.0` and `## v1.4.0` a single stable
   spelling rather than two sections).
2. **Section exists** → **replace it in place**: swap the section's body for the freshly aggregated
   content, leaving its position and every other section byte-identical. A re-run with no new merged
   stories therefore rewrites the section with identical bytes → empty `git status --porcelain` → no
   commit, no PR.
3. **Section absent** → **prepend** a new `## <VERSION>` section above the newest existing section,
   preserving newest-first ordering.

The upsert boundary is the `## <VERSION>` heading and everything up to (not including) the next
`## ` heading or EOF — **including** the `### `-level change-type sub-headings inside it, which are
section body, not section boundaries (see "Deterministic ordering" above; change-type buckets MUST
use `### `, never `## `, or the boundary detection breaks). The file's preamble is never touched.

## 12. Release mode — ADR-link resolution + artifact set

### ADR-link resolution

For each merged-story key, resolve its **motivating ADR** by scanning `docs/adr/**` frontmatter for
any ADR whose `source-stories:` list contains that key (the join key established by
`refs/adr-pipeline.md`):

- **Match** → the release note for that story links the ADR (relative link to the
  `docs/adr/NNNN-*.md` page, using the ADR title).
- **No match** → the note **omits** the ADR link entirely. Never fabricate, guess, or invent an ADR
  reference. A story with no ADR simply has an ADR-less note.
- Multiple ADRs may cite the same story → link each.
- The scan is **read-only** against `docs/adr/` at `origin/<BASE-BRANCH>` head — resolve it
  checkout-independently (`git ls-tree -r --name-only origin/<BASE-BRANCH> -- docs/adr` then
  `git show origin/<BASE-BRANCH>:<path>` per hit), never out of the working tree.
- **No `docs/adr/` directory at all** → every note is ADR-less. Not an error.

### Artifact set

Each artifact maps onto an existing `writing-docs` quadrant template and its registry `target-path`;
the **normalised** `VERSION` is the identifier. **A row is only in play when it is in
`ENABLED_ROWS`.**

| Artifact          | Quadrant    | `writing-docs` template | Default `target-path`    | Convention                                                                          |
| ----------------- | ----------- | ----------------------- | ------------------------ | ----------------------------------------------------------------------------------- |
| `changelog`       | reference   | Reference               | `docs/changelog/`        | Single **cumulative** `index.md`; each release **upserts** its `## <VERSION>` (§11) |
| `release-notes`   | explanation | Explanation             | `docs/release-notes/`    | **One page per version**, `<VERSION>.md`; each note links its motivating ADR(s)     |
| `migration-guide` | how-to      | How-to                  | `docs/migration-guides/` | **One stub page per version**, `<VERSION>.md` — headings/scaffold only              |

- The **changelog** is a gated artifact but **not a narrative one**: its body is a mechanical
  aggregation of the commit range (§11), so the founder confirms an aggregation, not prose.
- **Release notes** are explanation-quadrant prose per `writing-docs` — one entry per merged story,
  each linking its motivating ADR when one exists. Fully narrative, fully gated.
- The **migration-guide stub** is headings/scaffold **only** — emit exactly:

  ```markdown
  ## Breaking changes

  ## Upgrade steps

  ## Rollback
  ```

  with **no body prose** under any heading. Deep migration content is explicitly out of scope.

### Page frontmatter (required — `llms.txt` reads it)

§8's `llms.txt` regen derives each entry from the generated page's frontmatter, so every written
release page MUST carry:

```yaml
---
title: <human title, e.g. "Release notes — 1.4.0">
description: <one line, used verbatim as the llms.txt description>
---
```

The migration-guide stub is a `how-to` page but **must NOT carry a `source:` key** — §5 makes a
`source:`-less how-to page one that `sync` never auto-refreshes, which is the intended behaviour for
a per-version stub (a release artifact is owned by the release that cut it, not re-drafted by a
later `sync`).

## 13. Release mode — branch / PR / control flow

> **Divergence from §7 — do not harmonise.** §7 (`sync`) resets the branch onto regenerated state
> and force-pushes with `--force-with-lease`, which is safe there because `sync`'s branch content is
> **fully derived**. A release branch is **not** fully derived: the control-flow tail drives
> `/loop /sdlc:loop` against it, so it carries review-fix commits not derived from the drafts.
> `reset --hard` and force-push are therefore **prohibited** on release paths. Re-run convergence
> comes from idempotence, not from rewriting history.

| Item                      | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Branch                    | `docs/release-<VERSION>` (the **normalised** version — `1.4.0` and `v1.4.0` resolve to the same branch, never two), cut from the **base branch head** (`origin/<BASE-BRANCH>`) — **not** a story branch. Release aggregates work already merged to base, so the base tree is the correct source.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Commit                    | `docs(docs): release <VERSION>` (via `conventional-commit`), carrying the trailer `Release-Generated: <VERSION>`. **The trailer is load-bearing**, not decoration: it is the only reliable marker of "this pipeline wrote this commit", and both guards below key on it. Subject-matching is not a substitute.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| PR title                  | `docs(docs): release <VERSION>`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| PR base                   | `<BASE-BRANCH>` from project-context (never assume `main`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Local-branch precondition | Applies on **every** path, first-run and re-run alike, checked **before** either. If a **local** `docs/release-<VERSION>` exists holding commits not reachable from `origin/docs/release-<VERSION>` (or, when no such remote exists, any commits at all beyond `origin/<BASE-BRANCH>`) → **STOP**: `local branch docs/release-<VERSION> has unpushed commits; push, drop, or rename it, then re-run.` Never `checkout -B` over it. Hoisted out of the re-run rows deliberately: the first-run path is defined by the branch being absent **on `origin`**, which says nothing about a local branch of the same name.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| First-run PR              | No remote branch (`git rev-parse --verify origin/docs/release-<VERSION>` fails) → after the precondition passes, create the branch from `origin/<BASE-BRANCH>` head, write, commit, push, open the PR against `<BASE-BRANCH>`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Re-run behaviour          | **Open or update; the branch's commits are never rewritten.** If the branch exists on `origin` → `git fetch origin`, run the precondition + **both guards**, then check it out **at its remote head**: `git checkout -B docs/release-<VERSION> origin/docs/release-<VERSION>` — **the single normative flow**. Write the regenerated content **on top** as a new commit and `git push` (plain fast-forward). A re-run with nothing to change produces **no commit, no push, no duplicate PR**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Re-run history guard      | The **one forbidden path**: no re-run may reset the branch onto regenerated state, force-push it (`--force` / `--force-with-lease`), or discard any commit reachable from `origin/docs/release-<VERSION>`. A reset-to-regenerated + `--force-with-lease` would _succeed_ (the local ref was just fetched) and silently revert the PR to unreviewed content. Checking out at the remote head does none of these — it adopts the remote's commits rather than replacing them.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Re-run content guard      | Preserving commits protects **history**; this guard protects **content**. Before writing, find commits on the branch (relative to `origin/<BASE-BRANCH>`) that touch **any path phase 2 writes this run** and **lack the `Release-Generated: <VERSION>` trailer** — i.e. out-of-pipeline edits to generated pages. This path set is **not** just the `ENABLED_ROWS` target-paths: phase 2 also unconditionally rewrites `llms.txt` (when §14 determines its row is enabled) and, per §14's "doc index" bullet, any existing `release-notes`/`migration-guides` section index page it regenerates — a `/sdlc:loop` review-fix or founder edit to either of those is exactly the kind of out-of-pipeline content this guard exists to protect, and scoping the scan to `ENABLED_ROWS` alone would silently destroy it with no STOP. If any qualifying path is found → **STOP**: `branch docs/release-<VERSION> carries edits to generated pages (<paths>) that this pipeline did not write; re-running would overwrite them — merge or close PR #<n>, or drop those edits, then re-run.` Necessary because phase 2 writes confirmed drafts **verbatim** and §11's upsert replaces the section body unconditionally. Trailer-bearing commits, and commits touching **other** paths, do not trip it — proceed. |
| Control-flow tail         | Mirror §7 / `commands/adr.md`: after the PR is raised, drive the review loop via `/loop /sdlc:loop <PR_URL>` (falling back to `ScheduleWakeup` if the harness cannot nest `/loop`). If the run ended **before** any PR (manifest-absent silent no-op, no-row-enabled no-op, no-stories-merged no-op, an invalid-version STOP, or a precondition/guard STOP), release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — only the manifest-absent path is silent.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |

### Where edits live, and what a re-run does to them

| Edit made…                                                                                | Committed by                                                 | A re-run…                                                                                                                                                                                                                                                   |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **At the founder-confirm gate** (the founder edits a draft before confirming it)          | phase 2, carrying the `Release-Generated: <VERSION>` trailer | **Re-derives it.** Phase 1 re-drafts from the commit range every run and the gate re-presents the machine draft — a prior run's gate edit is **not** carried forward. To keep it, re-apply it at this run's gate. Not silent, but **not preserved either**. |
| **On the branch, outside the pipeline** (a `/sdlc:loop` review-fix commit, a direct push) | anything **without** the trailer                             | **STOPs** (re-run content guard) — refuses to overwrite it and hands the decision back to the founder.                                                                                                                                                      |

The distinction is the **trailer, not the commit subject**. Keying on the subject would be wrong:
phase 2 commits founder gate edits under exactly the normal `docs(docs): release <VERSION>` subject,
so a subject test classifies them as pipeline-authored and the guard never fires — correct for gate
edits (re-derived by design), but it must not be mistaken for _preserving_ them.

## 14. Release mode — no-op / change-gate semantics

- **Manifest-absent silent no-op.** See [§1's Manifest gate](#manifest-gate-shared-by-sync-release-and-seed)
  (shared with `sync`) — the command layer never dispatches when that gate finds the manifest
  genuinely absent, distinct from the STOP the same gate raises first if `origin/<BASE-BRANCH>`
  itself won't resolve. Not something phase 1 checks. The zero-setup-cost guarantee for repos that
  declined the `/init` docs opt-in.
- **No release row enabled → clean no-op.** Print `no release-triggered doc types enabled in
docs-manifest.md — nothing to generate` and exit without a PR. **Informational, not silent** — the
  manifest exists, so the founder opted in; a fully-disabled release surface is worth surfacing
  (mirroring `sync`'s "found nothing to do" vs "opted out" distinction).
- **No stories merged → clean no-op.** Interpolate `LAST_TAG` **only when set** — never emit an
  empty interpolation:
  - `LAST_TAG` set → `no stories merged since <LAST_TAG> — nothing to release`
  - `LAST_TAG` empty → `no stories merged since the start of history — nothing to release`
- **Commit/PR only on actual content change.** Phase 2 commits only if `git status --porcelain` on
  the written paths is non-empty. If the founder rejected every draft and the deterministic regen
  produced byte-identical output → no commit, no PR, clean exit. If the founder rejected the
  narrative drafts **but** the deterministic `llms.txt`/index changed → still commit + PR.
- **`llms.txt` regenerated every run, committed only if changed.**

### Re-run / idempotence contract

Re-running `release <VERSION>` over the **same commit range**, with the founder confirming the
**same content**, recomputes **byte-identical** content for every enabled row, leaves
`git status --porcelain` empty, and therefore commits nothing and opens no PR.

**The claim is scoped, and the scope is load-bearing.** It is a statement about the _generator_:
same range + same confirmed content → same bytes. It does **not** claim edits survive a re-run
untouched — see §13's "Where edits live". Five things are load-bearing; none may be dropped:

1. **`VERSION` normalisation** — one spelling per release, so a re-run targets the same branch, PR,
   pages, and changelog section rather than creating a parallel set.
2. **Changelog upsert** (§11) — a re-run rewrites its section in place instead of prepending a duplicate.
3. **A parseable enumeration** (§10) — the RS/US delimited format; without it "the commit that
   carried the key" is underivable and the aggregation is not a function of anything well-defined.
4. **Content is a pure function of the commit range** (§11) — no `gh`, no network, no ambient state
   may reach a written byte, or "byte-identical" would depend on whether `gh` happened to answer.
5. **Non-destructive branch re-use** (§13) — a re-run preserves every commit on the branch (never
   resets onto regenerated state, never force-pushes) and STOPs rather than overwrite out-of-pipeline
   edits to generated pages.

### Deterministic index + `llms.txt` regen

After the confirmed narrative writes, phase 2 deterministically regenerates the doc index and
`llms.txt` — the un-gated half of the run (the same "auto rows are un-gated" discipline `sync` applies):

- **`llms.txt`** — **only if the `llms-txt` row is present and enabled in the manifest.** `llms-txt`
  is a `sync`-triggered row, not a `release`-triggered one, so it is **not** a member of
  `ENABLED_ROWS` (`commands/docs.md`'s Enabled-row gate covers only the three release rows) —
  release must independently re-check the manifest's `llms-txt` row state before touching this
  file. Absence is
  never inferred as enabled, the same discipline as `ENABLED_ROWS`'s row-absence rule: a founder who
  declined `llms-txt` at `/init` (row absent, per `docs.md`'s "Absent is never default-on" rule)
  must never have it written or overwritten by a `release` run either. If disabled or absent, phase 2
  does not write or touch `llms.txt` at all this run — any existing file is left exactly as-is. When
  it **is** enabled: reuse §8's algorithm verbatim — index-only, grouping the generated pages of
  every enabled `public: yes` row by Diátaxis quadrant, each entry a `title — one-line description —
relative link` derived from page frontmatter (§12 specifies the frontmatter release pages emit).
  The newly written release pages now appear in it. Idempotent; committed only if changed.
- **The doc index** — for the `changelog` target-path, the cumulative file **is** the index of
  releases (newest-first), maintained in place by §11's upsert. For `release-notes` /
  `migration-guides`, if the row is enabled **and** the consumer's docs tree already carries a
  section index page at that path, regenerate it deterministically (**upsert** the `<VERSION>` entry
  — add if absent, rewrite in place if present; never append a duplicate). If none exists,
  `llms.txt` is the sole index and no separate section index is created. No new index file type is
  invented.

## 15. Seed mode — type resolution + topic validation

### `SEED_TYPES` — registry-derived, never hardcoded

`SEED_TYPES` resolves **at read time** from `refs/doc-types.md`: every row whose `trigger` cell
contains the `seed` token, **minus `adr`** (deferred to NA-57). Today that resolves to `concept`,
`tutorial`, `integration-guide`, and `how-to`.

**Why derived and not a literal list in `docs.md`.** `refs/doc-types.md` is the stated single source
of truth for `trigger` (`docs-manifest-template.md`: consumers "derive all four from
`refs/doc-types.md` at read time"). A hardcoded list would be a second copy of a normative fact and
would drift the moment a row's `trigger` changes. `seed` reads the registry; the registry decides.
Any message that enumerates the valid types **renders the resolved `SEED_TYPES`** — it never types
the list as a literal, or it becomes the copy this rule exists to avoid.

`refs/doc-types.md` unreadable or malformed → surface the failure and **STOP**. Never resolve
`SEED_TYPES` from a partial registry, and never fall back to a hardcoded list.

**`adr` is excluded from `SEED_TYPES` rather than admitted-then-rejected downstream**, so no `adr`
run can reach the manifest gate, the branch, or the write path. `seed adr` is a **clean stub**, not
a usage error — `adr` is a legitimate registry row carrying `seed`, and NA-57 implements it against
the retained `refs/adr-pipeline.md`:

```text
seed type "adr" is not yet implemented (see NA-57) — use /sdlc:adr until it lands
```

Printed, exit 0. The pointer to the still-live `/sdlc:adr` is load-bearing: **NA-57 removes that
command, and NA-57 is the story that must also delete this stub.**

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
§13's version ladder — **structurally vacuous**. A vacuous rule is not free: NA-53 shipped a `.lock`
check that rejected nothing and an unreachable trailing-`-` STOP whose message misdescribed its
input, and both survived review because nobody tested them. So, explicitly:

- **No `..` rule.** `.` is not in the charset; `x..y` → `x-y`. Unreachable.
- **No `.lock` rule.** `1.4.lock` → `1-4-lock`. Verified:
  `git check-ref-format --branch docs/seed-concept-1-4-lock` → **valid**. A `SLUG` cannot end in
  `.lock` because it cannot contain a `.`. Unreachable. (§13 needs this rule; `seed` does not.
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

The seed run reuses §2's two-phase dispatch and command-layer founder-confirm gate — **not
re-derived here**. What is seed-specific, **in this order** (the order is load-bearing):

```text
1. argument validation (§15)  →  2. manifest gate (§1)  →  3. type-activation gate
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
   [§1's Manifest gate](#manifest-gate-shared-by-sync-release-and-seed). `seed` is its third
   consumer and does **not** re-derive it. The base-ref pre-check ordering is load-bearing for
   exactly the reason §14 documents: a bare `git show origin/<BASE-BRANCH>:<path>` failure is
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
   instance of §3's "never touches an unaffected row's pages" invariant — regenerates the index +
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

**This is a real gap in the templates, not a restatement of an existing rule.** Verified by
inspection of `writing-docs/SKILL.md`: the **How-to guide template** is the only one that emits
frontmatter (`title` + the `source:` glob list); the **Tutorial**, **Reference**, and
**Explanation** templates emit **no frontmatter block at all**, and **none of the four** emits
`description:`. Three of `seed`'s four types would, template-faithfully, produce a page with no
frontmatter whatsoever.

The consequence: §8's `llms.txt` regen derives every entry from the page's frontmatter
(`title — one-line description — relative link`). A seeded page with no frontmatter either **drops
out of `llms.txt` silently** — published but invisible to the index that exists to expose it, the
exact failure `seed` prevents — or makes the regen fail on a page it expects to carry frontmatter.

**Where the check lives is itself load-bearing:** phase 1 emits the frontmatter; **the command layer
validates it at the founder-confirm gate**, where the content still exists and the founder can fix a
missing line in situ. It is **NOT** deferred to phase 2 — a fresh dispatch holding an opaque payload,
which can only STOP, losing a four-hundred-line authored page to a one-line defect and reintroducing
the "STOP after the founder has authored" failure this rule exists to prevent. Phase 2 MAY keep a
defensive assertion, but it **must preserve the content** (session temp dir + surfaced path) rather
than discard it.

### `source:` frontmatter — `how-to` and `integration-guide` only

Both map onto the how-to quadrant, whose template emits a `source:` glob list. §5 is normative and
unchanged: a how-to page **with** `source:` is auto-refresh-drafted by `sync` when `CHANGED_FILES`
intersects its globs; a page **without** it is **never** auto-refreshed — the deliberate opt-in
boundary. `seed` **is** that founder action, and the natural moment to make the choice:

- The scaffold presents the `source:` list (with the template's explanatory comment) at the gate, and
  the founder supplies globs or removes the key.
- **Founder supplies globs** → the page is written with `source:`; future `sync` runs draft refreshes
  of it. This is the seed → sync handoff that makes `how-to`'s `seed,sync` trigger coherent.
- **Founder omits it** → the key is **omitted entirely** (never written empty). Per §5 the page is
  simply never auto-refreshed. Not an error, and **not something `seed` may infer a value for** —
  inferring globs would opt the founder into automated refreshes of a page they hand-authored.
- `concept` and `tutorial` pages **never** carry `source:` — it is a how-to-quadrant key and §5's
  match semantics apply only to how-to rows. Do not emit it for them.

## 18. Seed mode — branch / PR / control flow

> **Divergence from §7 — do not harmonise.** §7 (`sync`) resets the branch onto regenerated state
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
| Branch                    | `docs/seed-<type>-<SLUG>` (the **normalised** slug — `My Topic` and `my-topic` resolve to the same branch, never two), cut from the **base branch head** (`origin/<BASE-BRANCH>`) — **not** a story branch. A seed authors a new page against current base; there is no story diff to read. Mirrors `commands/adr.md`'s `docs/adr-<slug>` shape, with `<type>` included because two types may legitimately seed the same topic (`docs/seed-concept-offline-sync` and `docs/seed-tutorial-offline-sync` are distinct pages and must be distinct branches).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| Commit                    | `docs(docs): seed <type> <SLUG>` (via `conventional-commit`), carrying the trailer `Seed-Generated: <type>/<SLUG>`. **The trailer is load-bearing**, not decoration: it is the only reliable marker of "this pipeline wrote this commit", and both guards below key on it. Subject-matching is not a substitute.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| PR title                  | `docs(docs): seed <type> <SLUG>`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| PR base                   | `<BASE-BRANCH>` from project-context (never assume `main`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Local-branch precondition | Applies on **every** path, first-run and re-run alike, evaluated at §16 step 5. If a **local** `docs/seed-<type>-<SLUG>` exists holding commits not reachable from `origin/docs/seed-<type>-<SLUG>` (or, when no such remote exists, any commits at all beyond `origin/<BASE-BRANCH>`) → **STOP**: `local branch docs/seed-<type>-<SLUG> has unpushed commits; push, drop, or rename it, then re-run.` Never `checkout -B` over it. Hoisted out of the re-run rows deliberately: the first-run path is defined by the branch being absent **on `origin`**, which says nothing about a local branch of the same name.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| First-run PR              | No remote branch (`git rev-parse --verify origin/docs/seed-<type>-<SLUG>` fails) → after the precondition passes, create the branch from `origin/<BASE-BRANCH>` head, write, commit, push, open the PR (`gh pr create`) against `<BASE-BRANCH>`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Re-run behaviour          | **Open or update; the branch's commits are never rewritten.** If the branch exists on `origin` → `git fetch origin`, run the precondition + **both guards at §16 step 5**, then (in phase 2) re-verify them and check it out **at its remote head**: `git checkout -B docs/seed-<type>-<SLUG> origin/docs/seed-<type>-<SLUG>` — **the single normative flow**. Write the confirmed content **on top** as a new commit and `git push` (plain fast-forward). A re-run where nothing changed produces **no commit, no push, no duplicate PR**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Re-run history guard      | The **one forbidden path**: no re-run may reset the branch onto regenerated state, force-push it (`--force` / `--force-with-lease`), or discard any commit reachable from `origin/docs/seed-<type>-<SLUG>`. A reset-to-fresh + `--force-with-lease` would _succeed_ (the local ref was just fetched) and silently revert the PR to unreviewed content. Checking out at the remote head does none of these.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Re-run content guard      | Preserving commits protects **history**; this guard protects **content**. Evaluated at §16 step 5, and **re-verified by phase 2 before writing** — mandatory, because phase 2 is the only layer that writes and the branch can move while the founder authors. Find commits on the branch (relative to `origin/<BASE-BRANCH>`) that touch **any path phase 2 writes this run** and **lack the `Seed-Generated: <type>/<SLUG>` trailer**. **That path set is NOT just `PAGE`**: phase 2 also rewrites `llms.txt` (when its row is enabled) and any regenerated section index page — a `/sdlc:loop` review-fix or founder edit to either is exactly the out-of-pipeline content this guard protects, and scoping the scan to `PAGE` alone would silently destroy it with no STOP. If any qualifying path is found → **STOP**: `branch docs/seed-<type>-<SLUG> carries edits to generated pages (<paths>) that this pipeline did not write; re-running would overwrite them — merge or close PR #<n>, or drop those edits, then re-run.` Trailer-bearing commits, and commits touching **other** paths, do not trip it — proceed. |
| Phase-2 TOCTOU re-check   | **MUST, not MAY.** The gate opens an authoring-length window in which the branch can move, and phase 2 is the **only** layer that writes: an optional re-check that an implementer skips would check out at the remote head and write straight over the out-of-pipeline edit the step-5 guard exists to protect, with no STOP. If a re-check STOPs, phase 2 **MUST preserve the confirmed content** — write it to the session temp dir (`scripts/tmp-dir.sh`) and **surface the path in the STOP** — never discard it. A guard that destroys the founder's page while protecting someone else's commit has traded one loss for another. Preservation is what makes a mandatory STOP here costless.                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Control-flow tail         | Mirror §7 / §13 / `commands/adr.md`: after the PR is raised, drive the review loop to convergence via `/loop /sdlc:loop <PR_URL>` (falling back to `ScheduleWakeup` if the harness cannot nest `/loop`). If the run ended **before** any PR (manifest-absent silent no-op, deactivated-type report, `adr` stub, founder-declined-at-gate, a usage STOP, a page-exists STOP, or a precondition/guard STOP), release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — only the manifest-absent path is silent.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |

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

§11 established that content written to a file must be a pure function of repo state — `gh`
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
`commands/adr.md` already draws: _"claude-mem tools absent in distill mode → halt distill … **Seed
mode is unaffected.**"_ The reason is structural: `distill`'s entire input **is** the corpus, so
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
  run — any existing file is left exactly as-is. When it **is** enabled: reuse §8's algorithm
  verbatim — index-only, grouping the generated pages of every enabled `public: yes` row by Diátaxis
  quadrant, each entry a `title — one-line description — relative link` derived from page
  frontmatter. The newly seeded page appears in it. Idempotent; committed only if changed.

- **Frontmatter-less pages the regen encounters are SKIPPED, never fatal, and never fabricated.**
  This story mandates frontmatter on the **page it writes**, but §8's algorithm reads frontmatter
  from **every** enabled `public: yes` page in the tree — and the templates emit none, so pages
  written before this rule existed (a hand-authored tutorial, a `sync`-drafted how-to) may well lack
  it. That exposure is pre-existing and shared with `sync`/`release`; `seed` merely walks into it.
  - A page missing `title`/`description` is **omitted from `llms.txt`** and its path **surfaced in
    the phase-2 output and the PR body**. Loud, not silent.
  - It is **never a STOP.** A STOP mid-phase-2 would **tear the write** — the founder's page
    committed, the index not — and would let an unrelated page's defect block a valid seed the
    founder just authored.
  - Its `title`/`description` are **never** inferred from the body or filename. That would fabricate
    published index copy, the fabrication boundary this pipeline holds everywhere else.

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
  `llms.txt` when that row is enabled. (`adr` is the registry's only `public: no` row — out of scope
  here, routed to NA-57.)

### No-op / change-gate semantics

- **Manifest-absent silent no-op (AC5).** See
  [§1's Manifest gate](#manifest-gate-shared-by-sync-release-and-seed) — the base-ref pre-check is
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
§14's idempotence contract ("same range + same confirmed content → same bytes") is a statement about
a **generator** whose input is repo state. `seed`'s page body has no such input: it is founder prose
typed at a gate. Re-running `seed concept offline-sync` re-prompts and re-authors; asserting
byte-identity would be false. **Do not copy §14's idempotence wording.**

| Property                                        | Holds?  | Scope / why                                                                                                                                                     |
| ----------------------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Page **identity** is stable across re-runs      | **Yes** | `SLUG` normalisation — one branch, one PR, one page id per topic, regardless of how the topic was typed                                                         |
| Page **body** is byte-identical across re-runs  | **No**  | It is founder-authored input, re-authored at each run's gate. No claim is made                                                                                  |
| **Write-time fidelity**                         | **Yes** | Phase 2 writes the confirmed content **verbatim** — the bytes written are the bytes the founder saw. **This, not byte-identity, is `seed`'s content guarantee** |
| **`llms.txt` / index regen** is deterministic   | **Yes** | Pure function of the enabled `public: yes` rows' page frontmatter (§8). Re-running over an unchanged page set yields byte-identical output                      |
| **Commit/PR only on actual content change**     | **Yes** | Phase 2 commits only if `git status --porcelain` on the written paths is non-empty                                                                              |
| Branch commits are **preserved** across re-runs | **Yes** | Never reset, never force-pushed — §18                                                                                                                           |
