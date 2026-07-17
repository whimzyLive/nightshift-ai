# Docs pipeline

Shared resolve → diff → regen → draft → founder-confirm → write → commit/PR protocol for
`/sdlc:docs sync` (§§2–8) and `/sdlc:docs release` (§§10–14), referenced by both
`agents/knowledge-engineer.md` and `commands/docs.md` so the
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

### Manifest gate (shared by sync and release)

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

- **Manifest-absent silent no-op (AC5).** See [§1's Manifest gate](#manifest-gate-shared-by-sync-and-release)
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

- **Manifest-absent silent no-op.** See [§1's Manifest gate](#manifest-gate-shared-by-sync-and-release)
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
