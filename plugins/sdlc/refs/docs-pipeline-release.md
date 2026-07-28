# Docs pipeline — release mode (§§10–14)

**Mode-specific slice for `/sdlc:docs release`.** Merged-story enumeration, changelog aggregation +
upsert, ADR-link resolution + artifact set, branch/PR/control flow, and no-op/change-gate semantics.
Read together with the shared foundation slice, `docs-pipeline-core.md` (§§1–9) — this slice does
not restate the manifest gate, the two-phase dispatch split, or the deterministic regen algorithm,
it only points back to them.

## 10. Release mode — merged-story enumeration

Release aggregates work **already merged to base**, so the diff source is `origin/<BASE-BRANCH>` —
never a story branch (contrast `docs-pipeline-core.md` §7, where `sync` cuts from the story branch head).

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
   silently dropped from the changelog). When parsing the "Additional Jira project keys" section
   body, **ignore HTML-comment spans, whitespace, and any `<...>`-bracketed placeholder token** —
   a section whose only non-whitespace content is a comment (e.g. a founder commented out their
   keys) or an unfilled `<...>` placeholder resolves to the **empty** additional-keys set (falling
   back to the primary key alone). The `<...>` skip is load-bearing, not merely defensive:
   `refs/docs-manifest-template.md`'s own section prose shows the shape as
   `<comma-separated list of legacy or secondary Jira project keys, e.g.: ET>` — a founder who
   copies that line verbatim to see the format and forgets to replace it would otherwise feed the
   bare `ET` to this resolver as a real key, silently scoping `release` to `ET-*`. Stripping any
   `<...>` span before parsing closes that hole regardless of what example text the template shows.

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

### Out-of-scope key warning (AC3 — gated on PROJECT_KEYS ≠ ∅)

This warning is a **pure announcement overlay** on the emission above — it never changes what is
emitted, only what is _announced_. It exists solely to surface keys that emission **drops**, and
emission only drops keys when `PROJECT_KEYS ≠ ∅` (the strict alternation is in force). Therefore
**the entire computation and every print below is guarded by `PROJECT_KEYS ≠ ∅`.**

**When `PROJECT_KEYS = ∅` (State A):** the loose fallback emits **every** shape-matched token, so
**nothing is out-of-scope** and this warning is **skipped entirely** — no computation, no no-op
override. The `∅` case already carries the loose-fallback gate risk note above; NA-60 adds nothing,
and **never routes `∅` into a suppressing no-op.** The run proceeds/emits exactly as this section
already defines.

**When `PROJECT_KEYS ≠ ∅`**, compute the following over the `(subject, body)` records already
enumerated for `RANGE` (no second enumeration, no `gh`, no network):

| Set                 | Definition                                                                                                                                                                                                  |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SHAPE_MATCHES`     | every **distinct** token matching the loose shape `\b[A-Z][A-Z0-9]*-[0-9]+\b` — the superset of what any emission mode could match                                                                          |
| `IN_SCOPE`          | tokens whose **prefix** (the `[A-Z][A-Z0-9]*` head — the char class admits no `-`, so it is unambiguous) is a member of `PROJECT_KEYS`. Exactly what NA-53 emits here.                                      |
| `OUT_OF_SCOPE`      | `SHAPE_MATCHES − IN_SCOPE` — every shape-matched token emission **drops**.                                                                                                                                  |
| `LIKELY_KEYS`       | `OUT_OF_SCOPE − (prefix ∈ STANDARDS_TOKEN_DENYLIST)` — out-of-scope tokens **not** matching a known-standards prefix → **listed individually** in the warning. **The warning fires iff `LIKELY_KEYS ≠ ∅`.** |
| `STANDARDS_MATCHES` | `OUT_OF_SCOPE ∩ (prefix ∈ STANDARDS_TOKEN_DENYLIST)` — out-of-scope tokens matching a known-standards prefix → **summarized in one aggregated line, never dropped**                                         |

`IN_SCOPE` is subtracted **first**, so a configured key sharing a denylisted prefix is never
mis-handled — it is removed as in-scope before the denylist is ever consulted.

**The trigger is `LIKELY_KEYS ≠ ∅`, never `OUT_OF_SCOPE ≠ ∅` (State C, refined).** `OUT_OF_SCOPE`
is a superset that also contains `STANDARDS_MATCHES`, and `STANDARDS_MATCHES` is a **demoted
addendum shown only inside an already-firing warning — it is never, by itself, what fires the
warning.** A range whose only out-of-scope tokens are standards-prefixed (e.g. commit bodies citing
`RFC-2119`/`SHA-256`, zero genuine unrecognised keys) has `LIKELY_KEYS = ∅` even though
`OUT_OF_SCOPE ≠ ∅` — that range takes the **clean** no-op (or the normal gate, no warning line), not
the warning path. Gating on `OUT_OF_SCOPE ≠ ∅` instead would fire a warning with an **empty**
individual-key list under an active header and a "register this as a Jira project" footer, driven
entirely by standards noise — exactly the inversion AC4's demotion exists to prevent. Every part of
the warning below — the header, the count, the individual list, the standards-demotion line, and the
remediation footer — is gated as **one unit** on `LIKELY_KEYS ≠ ∅`; none of them renders on its own.

**`STANDARDS_TOKEN_DENYLIST` (fixed plugin constant, prefix-level):** `{ UTF, SHA, AES, RFC, ISO }`,
seeded from this repo's verified false-positives. It is a **display demotion, never a suppression**
(AC4). Emission continues to rely on `PROJECT_KEYS` scoping alone — the denylist changes only the
_prominence_, never the _presence_, of the notice:

- `LIKELY_KEYS` → listed individually (they look like real missing stories).
- `STANDARDS_MATCHES` → folded into a single aggregated, clearly-demoted line that is **still shown**,
  whose parenthesised prefix list is **the distinct set of prefixes actually folded this run**
  (interpolated from `STANDARDS_MATCHES`), never fixed illustrative text:

```text
(M token(s) matched common-standards prefixes (<distinct folded prefixes, e.g. RFC, SHA>) and were not listed individually — if any names a real Jira project, add its prefix as above.)
```

`M` is `|STANDARDS_MATCHES|` — a distinct variable from the warning's own total-dropped count
(`N` in `commands/docs.md`'s warning text, `= |LIKELY_KEYS| + |STANDARDS_MATCHES|`), never the same
letter as the total. This line renders only when `STANDARDS_MATCHES ≠ ∅` **and** the warning is
already firing (`LIKELY_KEYS ≠ ∅`) — it is an addendum inside a firing warning, never a trigger on
its own.

**Invariant (must hold on every path): no shape-matched out-of-scope token is ever dropped with zero
notice.** A token is emitted (`∈ PROJECT_KEYS`), listed individually (`LIKELY_KEYS`), or counted in
the summary line naming its prefix (`STANDARDS_MATCHES`). A real Jira project literally keyed `RFC`
(`RFC-14`) is **indistinguishable by shape** from the standard `RFC-2119`, so a full-suppression
denylist would either over-warn on the standard or silently drop the real key — which is why the
denylist **cannot** suppress. `RFC-14` is folded into the summary, whose interpolated prefix list
shows `RFC`, and the founder — reading "if any names a real Jira project, add its prefix" against a
prefix they recognise — adds it. No silence, no anonymous count.

**Who computes and prints it:** the **command layer** (`commands/docs.md`) computes `OUT_OF_SCOPE`
and its `LIKELY_KEYS`/`STANDARDS_MATCHES` partition at its release route (it already runs this §10
enumeration and owns the interactive gate), fires the warning **iff `LIKELY_KEYS ≠ ∅`**, and prints
it at the no-op branch (§14) or the founder-confirm gate. This ref owns only the definitions.
`agents/knowledge-engineer.md` is **not** involved — it never renders the gate.

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

`docs-pipeline-core.md` §8's `llms.txt` regen derives each entry from the generated page's frontmatter, so every written
release page MUST carry:

```yaml
---
title: <human title, e.g. "Release notes — 1.4.0">
description: <one line, used verbatim as the llms.txt description>
---
```

The migration-guide stub is a `how-to` page but **must NOT carry a `source:` key** — `docs-pipeline-core.md` §5 makes a
`source:`-less how-to page one that `sync` never auto-refreshes, which is the intended behaviour for
a per-version stub (a release artifact is owned by the release that cut it, not re-drafted by a
later `sync`).

## 13. Release mode — branch / PR / control flow

> **Divergence from `docs-pipeline-core.md` §7 — do not harmonise.** `docs-pipeline-core.md` §7 (`sync`) resets the branch onto regenerated state
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
| Control-flow tail         | Mirror `docs-pipeline-core.md` §7 / `refs/adr-pipeline.md`'s §3a: after the PR is raised, drive the review loop via `/loop /sdlc:loop <PR_URL>` (falling back to `ScheduleWakeup` if the harness cannot nest `/loop`). If the run ended **before** any PR (manifest-absent silent no-op, no-row-enabled no-op, no-stories-merged no-op, an invalid-version STOP, or a precondition/guard STOP), release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — only the manifest-absent path is silent.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |

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

- **Manifest-absent silent no-op.** See [`docs-pipeline-core.md` §1's Manifest gate](docs-pipeline-core.md#manifest-gate-shared-by-sync-release-seed-and-audit)
  (shared with `sync`) — the command layer never dispatches when that gate finds the manifest
  genuinely absent, distinct from the STOP the same gate raises first if `origin/<BASE-BRANCH>`
  itself won't resolve. Not something phase 1 checks. The zero-setup-cost guarantee for repos that
  declined the `/init` docs opt-in.
- **No release row enabled → clean no-op.** Print `no release-triggered doc types enabled in
docs-manifest.md — nothing to generate` and exit without a PR. **Informational, not silent** — the
  manifest exists, so the founder opted in; a fully-disabled release surface is worth surfacing
  (mirroring `sync`'s "found nothing to do" vs "opted out" distinction).
- **No stories merged → split by `LIKELY_KEYS` (§10), never by `OUT_OF_SCOPE`.** The emitted set
  here is NA-53's `IN_SCOPE`. When `PROJECT_KEYS ≠ ∅`, `OUT_OF_SCOPE` (and its `LIKELY_KEYS` /
  `STANDARDS_MATCHES` partition) is computed over the full range **regardless of whether `IN_SCOPE`
  is empty** (§10), so this no-op splits **on `LIKELY_KEYS`, one mutually-exclusive state — never
  both branches for the same range:**
  - emitted set `= ∅` **and** (`PROJECT_KEYS = ∅` **or** `LIKELY_KEYS = ∅`) → the existing clean
    no-op, interpolating `LAST_TAG` **only when set** (never an empty interpolation):
    - `LAST_TAG` set → `no stories merged since <LAST_TAG> — nothing to release`
    - `LAST_TAG` empty → `no stories merged since the start of history — nothing to release`
    - **`LIKELY_KEYS = ∅` covers the standards-only case too** — a range whose only out-of-scope
      tokens are standards-prefixed (`STANDARDS_MATCHES ≠ ∅` but `LIKELY_KEYS = ∅`) takes this clean
      branch, not the warning branch (see §10's refined State C — the demotion must never itself be
      what suppresses "nothing to release").
  - emitted set `= ∅` **but** `PROJECT_KEYS ≠ ∅` **and** `LIKELY_KEYS ≠ ∅` → **the warning no-op**
    (the pure silent-drop case — at least one genuine unrecognised key exists). Print the §10 warning
    (out-of-scope keys + section-aware remediation, per `commands/docs.md`); the message must **not**
    claim unqualified "nothing to release". Exit 0, still **no PR** — the pipeline never fabricates a
    release from unconfigured keys; it prompts the founder to configure and re-run.

  Because the split is keyed on the single variable `LIKELY_KEYS` (empty vs. non-empty), the two
  branches above are **structurally mutually exclusive** — no range can match both, so there is no
  precedence question and no risk of a legacy-key range silently falling into the clean branch.

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
  it **is** enabled: reuse `docs-pipeline-core.md` §8's algorithm verbatim — index-only, grouping the generated pages of
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
