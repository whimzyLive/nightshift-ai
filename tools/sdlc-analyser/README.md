# sdlc-analyser

Manual measurement tools for NA-86/NA-87/NA-88/NA-89/NA-90 (instruction-load reduction,
artifact-encoding reproducibility, duplicate-read classification, rtk rewrite-coverage replay,
read-bounding/carve-out volume). Read-only: these scripts read the repo and
`~/.claude/projects/**/*.jsonl` transcripts, and never write to either. Mostly not wired into CI
(`artifact-encoding.test.sh`, shipped under `plugins/sdlc/scripts/__tests__/`, was the original
exception — see `artifact-contract.sh` below for why that tool stays out of CI; `read-bounding.py`
below is a second exception, CI-wired because it needs no local binary, only stdlib Python and
in-repo fixtures) — run the rest by hand and paste the output into a PR body.

## `instruction-inventory.sh`

```text
bash tools/sdlc-analyser/instruction-inventory.sh [--root <dir>] [--padding] [--base <git-ref>] [--json]
```

Scans every file under `<root>/**/*.md`. `--root <dir>` defaults to `plugins/sdlc` so every
existing invocation and every NA-86 measurement block reproduces byte-identically; a root that
does not exist fails loud with the resolved absolute path and exits 1 — it never silently falls
back to `plugins/sdlc`. `--padding` and `--base` compose with `--root` unchanged (`--base` scopes
its `git ls-tree` by the resolved `$scan_root`).

One row per file: `path`, `bytes`, `estTokens`, `category`, `vendored` (`true` for
`plugins/sdlc/skills/find-skills/**` and `plugins/sdlc/skills/skill-creator/**`, which only ever
fires when `--root` resolves under `plugins/sdlc`). Vendored rows are excluded from every total.

**The `category` rule.** Determined once per run: if `<root>` contains at least one of the
recognised top-level category directories `commands/ agents/ refs/ skills/ scripts/`, `category` is
`command | agent | ref | skill | script | other` exactly as before (`other` for any unrecognised
sub-path) — this is the `plugins/sdlc` default's behaviour, unchanged. If `<root>` contains **none**
of those five directories (e.g. `--root docs/superpowers`), every row's `category` is `artifact` —
there is no meaningful command/agent/ref/skill/script split for a tree of produced artifacts.

`estTokens = floor(bytes / 3.7)`, computed per row; every total is the sum of the row-level
values it reports (not a separate floor over the aggregate byte count) — the report you can add
up by hand always matches the totals line.

`--base <git-ref>` recomputes the same inventory at that ref (via `git show <ref>:<path>` over
the file list from `git ls-tree -r --name-only <ref>`) and adds `totalEstTokensAtBase` /
`deltaEstTokens` (`current - base`; negative = saving). An unresolvable ref fails loud: prints the
ref name and exits 1 — it never silently reports a delta against `HEAD`.

`--json` emits the `InstructionInventoryReport` contract; without it, a human-readable table.

### The padded-row counting rule (`--padding`)

Two counts, reported separately and **never merged**. Fenced code blocks (` ` ```delimited)
are excluded from both — a`|`-shaped line inside a fence is not a table row.

1. **`paddedContentRows` — the headline figure.** A table **content** row: a line that, trimmed,
   starts and ends with `|`, is not an alignment/delimiter row (see below), and is not the first
   (header) row of its table. It counts as padded when the line contains at least one run of
   **2 or more consecutive spaces** immediately between a `|` and the adjacent cell content, on
   either side.
2. **`paddedDelimiterRows`.** A table's alignment/delimiter row — its cells, once trimmed, contain
   only `-` characters with an optional leading and/or trailing `:`. It counts as padded when any
   cell's dash run is longer than 3 (the unpadded convention this story produces is `| --- |`,
   exactly 3 dashes, one space either side).

Row classification inside one contiguous block of `|`-delimited lines: row 1 is the header (never
counted), row 2 is the delimiter row (checked against rule 2, never counted against rule 1), rows
3+ are content rows (checked against rule 1). A blank line, or any non-table line, ends the current
table; the next `|`-delimited line starts a fresh block at row 1.

Two other plausible rules exist on this tree and give materially different totals (639 vs 746
content rows) — an unstated rule makes before/after numbers non-reproducible. This is why the rule
is written out above instead of left to a hand grep. **When `--padding`'s count disagrees with a
hand grep, the tool wins** — a hand grep's rule is unstated, this one is not. Re-read this section
before overriding the tool's number.

## `branch-inventory.sh`

```text
bash tools/sdlc-analyser/branch-inventory.sh <file> [--base <git-ref>]
```

Counts **distinct decision outcomes** in `<file>`, once for the working tree (`OUTCOMES_HEAD`) and
once at `--base` (`OUTCOMES_BASE`; equal to `OUTCOMES_HEAD` when `--base` is omitted — nothing to
diff against). Emits `FILE`, `OUTCOMES_BASE`, `OUTCOMES_HEAD`, `OUTCOMES_MATCH` (`true`/`false`),
one `KEY=value` per line.

### The branch-outcome counting rule

One outcome per:

- Each `if` / `elif` / `else` line (bash keyword at the start of the trimmed line).
- Each `case` arm — detected as one outcome per `;;` occurrence on a line (a case arm's closing
  token), so a line with two arms (`0|1) ;; *) ... ;;`) counts two.
- Each `ASSERT`/`ELSE` pseudocode pair — one outcome per literal `ASSERT` occurrence.
- Each markdown decision-table row — every non-header, non-delimiter row of a `|`-delimited table
  block (same row-1-header / row-2-delimiter / row-3-plus-counted classification used by
  `instruction-inventory.sh --padding`), scanned across the whole file.
- Each explicit failure / `STOP` / `blocked` path stated in prose outside a table row or an
  if/elif/else/case line — one per line containing the standalone token `STOP` or the literal
  `blocked`, so a table row's own `STOP`/`blocked` text is never double-counted against the row it
  already counted.

`--base <ref>` recomputes the same count against `git show <ref>:<file>`; an unresolvable ref
fails loud (prints the ref name, exit 1) rather than comparing against `HEAD` silently. If `<ref>`
never contained `<file>`, `OUTCOMES_BASE=0`.

A file that cannot be read at all (missing or unreadable in the working tree) is **unparseable**:
emits `FILE`, `OUTCOMES_HEAD=-1`, a one-line `REASON=`, and exits 2 — the author supplies a manual
count in the PR body instead. `OUTCOMES_MATCH=false` exits 1 and blocks the PR: a lost `else` or
failure branch is a semantic regression, not a formatting nit.

**Escalation rule (applies to both tools):** when the tool's count and the author's manual count
disagree, the manual reconciliation wins and must be written into the PR body — the tool is an aid
to catch regressions mechanically, never the authority on what the "correct" count should have
been. `artifact-contract.sh` (below) is a third tool this same escalation rule applies to.

## `artifact-contract.sh`

```text
bash tools/sdlc-analyser/artifact-contract.sh --extract <path> [--section "<heading>"] [--fence <n>[,<n>...]]
bash tools/sdlc-analyser/artifact-contract.sh --template <path> [--section "<heading>"] [--fence <n>[,<n>...]] --artifact <path>
```

Extracts the **content contract** of a template (or any markdown file) and, in the second form,
diffs it positionally against a produced artifact — the instrument NA-87's AC-3 tier-1 gate and its
AC-5 measurement block both depend on. **Manual / author-run, deliberately not CI-wired (D7):** a
CI job would need a produced artifact to diff against, and none exists at CI time for a spec/plan/
ADR/review-round/rule-entry template — the implementer runs this by hand, pastes the output in the
PR body, and does not request merge on a failure; the reviewer checks the pasted output.
`plugins/sdlc/scripts/__tests__/artifact-encoding.test.sh` (CI-side) is a different, narrower guard
(pointer line + no in-fence padding) and does not replace this tool.

### The content-contract extraction rule

A contract item is any of, **in file order**:

1. **heading** — every ATX heading (`#`…`######`), taken verbatim including its level. The
   extractor **descends into fences**: a `## Overview` line inside a ` ```markdown ` template fence
   **is** a heading item — fences are content, not skipped regions.
2. **field** — every `<key>:` at the start of a trimmed line inside a fenced ` ```yaml ` block. A
   document-**leading** `---` … `---` YAML frontmatter block (the file's own first line is exactly
   `---`) is treated as a ` ```yaml ` fence for this rule and contributes no `fence` item of its
   own. **This does not extend to a `---` … `---` block nested inside a code fence elsewhere in the
   file** (e.g. an ADR template's own illustrative frontmatter sample shown inside its
   ` ```markdown ` template fence) — only an actual ` ```yaml `-labelled fence, or the whole
   document's own leading frontmatter, triggers rule 2. A nested illustrative `---` block extracts
   no field items; this is a known, deliberate scope limit, not a bug — state it in a PR body if a
   template relies on one.
3. **fence** — every fence's info string (` ```bash `, ` ```typescript `, …), counted **once per
   fence**, including fences nested inside a larger fence (distinguished by backtick-run length,
   e.g. a ` ```typescript ` sample nested inside an outer ` ````markdown ` template fence — the
   inner fence's shorter backtick run cannot close the outer one, so both are recognised as
   separate fences). An empty-info fence (` ``` ` alone) yields a fence item with value `` (empty
   string) — it still occupies a position. A fence never closed before EOF is treated as extending
   to the end of the selected span.
4. **literal** — every backtick-quoted inline span (on any line, fenced or not) that classifies as,
   first-match-wins: **path** = contains `/` and no whitespace; **command** = first
   whitespace-separated word ∈ `{bash, git, gh, acli, pnpm, npm, npx, python3}`; **ALL-CAPS token**
   = matches `^[A-Z][A-Z0-9_]*$` with length ≥ 2. Anything else (including a span whose only content
   is markdown escaping around embedded backticks, e.g. an inline reference to a fence's own
   backtick sequence) is not an item — the extractor trims the span before classifying it, but does
   not otherwise try to disambiguate prose-about-syntax from real literals.

**Prose is never a contract item** — that is exactly the surface NA-87 workstream B is allowed to
compress. Table rows outside a `<key>:`-shaped yaml field are never items either.

### `--section` and `--fence` selectors (template side only)

Added because the one-template-one-artifact contract is otherwise unsatisfiable for four of NA-87's
five templates — each is a sub-section (often a fenced sub-block) of a larger instruction file, not
the whole file.

- `--section "<exact heading text>"` — restrict extraction to the span from that heading (excluded)
  to the next heading of the **same or higher level**. The heading search — both for the named
  heading and for the next-heading span boundary — only considers **structural** headings (ones not
  inside any fence); a heading-shaped line inside a template's own fenced content (e.g. an ADR
  template's `# NNNN. …` sample heading) never terminates a `--section` span early. Unknown heading
  → error naming the heading, **exit 2**.
- `--fence <n>[,<n>...]` — within the selected span (or the whole file when `--section` is absent),
  select the _n_-th fenced block(s), 1-based **in file order among fences whose opening line falls
  in that span** (nested fences count in that same file-order sequence), and extract from their
  **contents only** — the selected fence(s)' own info string is not itself emitted as an item, but
  any fence nested _inside_ a selected fence still is. Multiple indices are extracted in ascending
  file order. An out-of-range index → error naming the index and the count found, **exit 2**.

`--extract` output: one item per line, exactly `<kind>:<line>:<value>` — `kind` ∈
`heading | field | fence | literal`, `line` is the 1-based line number **in the source file** (not
the span), `value` is the item verbatim. `kind` and `line` never contain `:`, so a consumer splits
on the first two colons.

### `--template <t> --artifact <a>` diff mode

The artifact side is always extracted **whole** — no selectors apply to `--artifact`. Comparison is
**ordered subsequence, placeholder-normalised** (NA-88 C7 — see "Why the matcher changed" below for
the defect this replaced):

1. **Ordered subsequence, not strict position.** A forward-only cursor over the artifact's ordered
   item list. For each template item _j_, scan artifact items from the cursor upward for the first
   match; on a match, advance the cursor to just past it. Artifact-side items the template does not
   name are **skipped, not treated as a mismatch** — a produced artifact is legitimately a superset
   of its template. A template item with no match found (scanning to the end of the artifact list
   from the cursor) is **missing**.
2. **Placeholder-normalised, whole-string match.** Item _i_ matches template item _j_ when `kind` is
   equal **and** the artifact value matches the template value's placeholder-normalised regex: every
   ERE metacharacter in the template value is escaped, then every placeholder run — bracketed
   `[...]`, angled `<...>`, or the bare ordinal token `NNNN` or `N` — is replaced with `.*`, then the
   whole pattern is anchored `^...$`. A bare `N`/`NNNN` run only counts as a placeholder when
   delimited by a non-alphanumeric/non-underscore character (or a string boundary) on **both**
   sides — so the `N` inside `NON` or `LEDGER_PHASE` is never wildcarded, and only a token that is
   genuinely just `N` or `NNNN` on its own is. Escaping happens **before** wildcard substitution, so
   a literal `[` or `1.` in a non-placeholder position is escaped, never treated as a regex opener.
   `## Phase N — [Domain] [agent-name]` matches `## Phase 1 — Tooling / measurement instrument ·
\`platform-engineer\``.

### Why the matcher changed (NA-88 C7)

NA-87's D12 tier-2 obligation — run the matcher against real, independently-produced artifacts
rather than the reference artifacts the same template-authoring agent generated to match its own
template — surfaced two independent causes of a near-total mismatch on real artifacts:
**(1) positional matching could not resynchronise** past any artifact-side heading the template does
not name (every real artifact has some — `## Scope map`, `## Global Constraints`, and so on), so one
extra heading aborted every subsequent comparison; and **(2) the old `is_placeholder()` rule made
any template value containing a placeholder marker match _any_ artifact value of the same kind at
that position**, regardless of whether the non-placeholder text actually corresponded — a blanket
match, not a real check. C7 replaces both: ordered-subsequence resynchronises past unnamed headings,
and whole-string placeholder-normalised regex matching validates the literal portions of a value
instead of waving the whole item through. **Regression proof:** all five NA-87 tier-1 reference
artifacts still report `CONTRACT_MATCH=true` (subsequence matching is a strict superset of exact
positional matching), and a deliberately dropped template heading still reports
`CONTRACT_MATCH=false` naming it — both proven in
`tools/sdlc-analyser/__tests__/artifact-contract.test.sh`.

```text
TEMPLATE=plugins/sdlc/skills/writing-specs/SKILL.md
ARTIFACT=docs/superpowers/plans/NA-87-measurements/ref-spec.md
CONTRACT_TEMPLATE=14
CONTRACT_ARTIFACT=14
CONTRACT_MISSING=
CONTRACT_MATCH=true
```

`CONTRACT_TEMPLATE` — count of items extracted from the template (after selectors).
`CONTRACT_ARTIFACT` — count of **those template items matched** in the artifact (not the artifact's
own total item count). `CONTRACT_MISSING` — ordered `;;`-separated list of `<kind>:<value>` for each
unmatched template item, empty string when none. `CONTRACT_MATCH` — `true` iff `CONTRACT_MISSING` is
empty.

**Exit codes, exactly:** `0` = `CONTRACT_MATCH=true`; `1` = mismatch; `2` = a path is unreadable or
a `--section`/`--fence` selector does not resolve — in that case the report is `TEMPLATE=`,
`ARTIFACT=`, `CONTRACT_ARTIFACT=-1`, `REASON=<what failed>`, and the author supplies a manual count.
**These non-zero exits are consumed by the author, never by CI** (D7) — `artifact-contract.sh` is
not wired into any CI job, on this repo or any fork.

## `duplicate-reads.py`

```text
python3 tools/sdlc-analyser/duplicate-reads.py <label> <transcript.jsonl>... [--per-story] [--json]
```

Python 3, stdlib only, read-only. Classifies every `Read` tool-use call in a transcript into one of
four classes and reports the redundant share — the instrument NA-88's C target and AC-4 depend on.

### The read-classification rule (verbatim — an unstated rule makes before/after non-reproducible,

the same discipline as the padded-row and content-contract rules above)

Within one transcript, for each `Read` tool-use in file order, with `whole := offset is None AND
limit is None` and a window's extent `[offset or 1, (offset or 1) + (limit or 2000) - 1]`:

```text
no earlier read of this path -> first read
any earlier read of this path was whole -> redundant                       # the whole file is already in the transcript
this read is whole AND an earlier read of this path exists -> redundant     # supersedes the earlier window, re-bills it
window intersects an earlier window of this path -> overlapping
otherwise -> disjoint                                                      # legitimate: a new region of a file read in parts
```

first-match-wins, top to bottom.

**Locating a `Read` call:** each transcript line is one JSON record; a `Read` tool-use is any item of
`record["message"]["content"]` (when it is a list) with `type == "tool_use"` and `name == "Read"`.
The path is `item["input"]["file_path"]` (after `os.path.expanduser` — no realpath resolution, so a
symlink alias is not provably a duplicate), the window is `item["input"].get("offset")` /
`item["input"].get("limit")`.

**Transcript partition — `(file, isSidechain)`, not the spec's literal "separate files" wording
(D9, gap fill).** The spec's unit is one `.jsonl` file per transcript. On this harness a subagent's
records can share the _same_ `.jsonl` file as the orchestrator's, distinguished only by
`isSidechain: true`. Classification state is therefore partitioned by **`(transcript path,
bool(record["isSidechain"]))`**, not by file alone — this implements D9's binding rule (a subagent's
context genuinely does not hold the orchestrator's reads) on this harness's actual record shape. A
path read by the orchestrator and again by a subagent in the same `.jsonl` file is never counted as
a duplicate of each other.

**Categories — exactly four `DuplicateReadCategory` values, derived from the path, first-match-wins:**

```text
plugins/sdlc/ in path, or both /plugins/ and /sdlc/ in path (a resolved plugin-cache path) -> plugin-instruction
docs/superpowers/ in path, or .claude/memories in path -> self-generated-artifact
.claude/ in path, or basename is CLAUDE.md or AGENTS.md -> project-config
otherwise -> source-other
```

`--per-story` groups by the story key parsed from each record's `gitBranch` (same `STORY_KEY_RE` /
`story_key()` as `cache-analysis.py`; unmatched → `unlabeled`) and prints one report section per
story.

`--json` emits the `DuplicateReadReport` contract verbatim (`label`, `sessions`, `totalReads`,
`firstRead`, `redundantAfterWhole`, `overlappingWindow`, `disjointWindow`, `redundantShare` —
`redundantAfterWhole / totalReads`, `0` when `totalReads == 0` — `byCategory`, `topPaths` — the 10
highest by `redundant`, ties broken by `reads` then `path`) plus `skippedLines`. Without `--json`, a
human-readable table with the same numbers.

**Fail-loud (`cache-analysis.py` precedent):** if no given path resolves to a readable file, prints
the paths tried to stderr and **exits 1** — never a zeroed report that reads like a real empty
result. **Unparseable line:** skipped, counted in `skippedLines`, and the scan continues — **exits
0**, because a truncated last line is normal in a live transcript.

## `read-bounding.py`

```text
python3 tools/sdlc-analyser/read-bounding.py <label> (<transcript.jsonl>... | --corpus-list <file>) [--threshold N] [--window-lines N] [--per-story] [--json]
```

Python 3, stdlib only (3.9-compatible), read-only. Classifies every `Read` tool-use call in a
transcript corpus by size and windowing, and reports the under-threshold carve-out — the
instrument NA-90's workstream-E gate (Global Constraint Decision 2, `>= 9,020 est tok/story`) is
scored against.

**CI wiring (NA-90 orchestrator decision, overriding the plan's Open item #3 default).** The plan
originally left this test author-run only, following the spec's Out-of-Scope line and the
`rtk-coverage.test.sh` precedent. That precedent does not transfer here: `rtk-coverage.test.sh`
needs a locally-installed `rtk` binary; `read-bounding.test.sh` needs only stdlib Python and
in-repo fixtures, so wiring it costs nothing and stops Gate-2 falsifiability rotting silently.
`.github/workflows/ci.yml` now runs `bash tools/sdlc-analyser/__tests__/read-bounding.test.sh`
directly.

### The read-sizing rule (verbatim — an unstated rule makes before/after non-reproducible)

```text
a Read call := an item of record["message"]["content"] with type == "tool_use" and name == "Read"
its result  := the item with type == "tool_result" and tool_use_id == that call's id
estTokens   := floor(len(result text) / 3.7)          # the bytes actually billed, not a file-size estimate
lines       := result text newline count + 1          # drives the windowed-cost model in Decision 2
windowed    := input.offset is not None OR input.limit is not None
whole       := NOT windowed
a call with no matched result -> excluded from every volume figure, counted in unmatchedCalls
```

### The corpus rule (verbatim)

```text
origin := subagent   IF the transcript path contains "/subagents/"
origin := orchestrator OTHERWISE
# isSidechain is NOT usable on this harness: 0 of 69,092 records carry it. Do not partition on it.
ASSERT corpus.subagentTranscripts > 0 ELSE print a loud one-line WARNING naming the
       */subagents/*.jsonl glob and that ~88% of read volume is likely missing
       # a warning, never exit 1 — a deliberately orchestrator-only run is legitimate
```

`isSidechain` is `0` across all 69,092 records on this harness. A non-recursive
`~/.claude/projects/*/*.jsonl` glob drops ~88% of read volume — it reduced NA-88's recorded
baseline to 798 of 6,793 reads (11.7%). Always glob `*/subagents/*.jsonl` explicitly. **This
story's own baseline (`docs/superpowers/plans/NA-90-measurements/read-bounding-before.txt`) uses
the RECURSIVE corpus rule** — `corpus-list.txt` is built from `<project>/*.jsonl` (top-level,
107 files) **union** `<project>/*/subagents/agent-*.jsonl` (550 files), generated via Python's
`glob.glob` rather than a shell `ls` (a local shell-hook rewrite was observed to append trailing
byte-size text to `ls` output on this machine, corrupting a naive corpus list — `glob.glob` sidesteps it
entirely). The resulting baseline shows `topLevelTranscripts: 107`, `subagentTranscripts: 550`,
`totalReads: 6085` — reproducing the spec's published figures within the expected drift from
corpus growth (`windowedShare` 26.06% vs spec's 26.1%; `topDecileShare` 51.68% vs 51.6%; `max`
25,188 matches exactly).

### The carve-out rule (verbatim)

```text
carveOutEligible := a read whose result is <= windowLines lines   # a windowed read here returns the whole file anyway
carveOutHits     := eligible reads taken WHOLE      # the carve-out was honoured
carveOutMisses   := eligible reads taken WINDOWED   # net LOSS: the Grep bought nothing
carveOutHitRate  := carveOutHits / carveOutEligible
# 468 of 681 addressable reads (68.7%) are eligible. An aggregate win with a low hit rate is
# a systematic loss on the majority, hidden by the mean — report both, always.
```

`--window-lines N` (default `400`) sets the carve-out line cap; `--threshold N` (default `2000`
est tok) is a separate, independently-settable unit — a windowed-read line cap and a whole-read
token cap measure different things and both must be re-derivable. `storiesObserved` is the count
of distinct story keys parsed from `gitBranch` across sized reads; `estTokensPerStory :=
totalEstTokens / storiesObserved` (`0` when `storiesObserved == 0`) is the exact unit Decision 2's
`9,020` gate is stated in, computed by the tool rather than by hand.

**Prefer `--corpus-list` over positional paths for any before/after comparison** — the
`rtk-coverage.py` reasoning: a sliding "most-recent-N" window is not the same bytes on both sides
of a delta.

**`--json` emits the full `ReadBoundingReport` contract**: `label`, `corpus`
(`topLevelTranscripts`, `subagentTranscripts`), `totalReads`, `windowedReads`, `windowedShare`,
`totalEstTokens`, `windowedEstTokens`, `p50EstTokens`, `p95EstTokens`, `maxEstTokens`,
`topDecileShare`, `wholeReadsOverThreshold`, `thresholdEstTokens`, `byOrigin` (both
`ORIGIN_ORDER` rows, always), `byCategory` (all four `CATEGORY_ORDER` rows, always), `topPaths`
(10 highest by whole-read volume, ties broken by reads then path), `skippedLines`,
`unmatchedCalls`, `windowLines`, `carveOutEligibleReads`, `carveOutHits`, `carveOutMisses`,
`carveOutHitRate`, `storiesObserved`, `estTokensPerStory`. Without `--json`, a human-readable
table carrying the same numbers.

**Error handling:** no given path resolves to a readable file -> every path tried is printed to
stderr, exit 1 (never a zeroed report that reads like a real empty result). Unparseable transcript
line -> skipped, `skippedLines += 1`, exit 0 (a truncated last line is normal in a live
transcript). `Read` call with no matching `tool_result` -> excluded from volume, `unmatchedCalls
+= 1`, exit 0. Non-numeric `--threshold` / `--window-lines` -> error naming the flag and the
value, exit 2.

### Gate 2 — falsifiability

| Corpus                                                                | `windowedShare` |
| --------------------------------------------------------------------- | --------------- |
| `all-windowed.jsonl` (synthetic, every read carries `offset`/`limit`) | `1.0`           |
| `all-whole.jsonl` (synthetic, no read carries either)                 | `0.0`           |
| real corpus (`NA-90-measurements/corpus-list.txt`, recursive)         | `~0.261`        |

A tool that returned the same number against all three would be incapable of measuring anything.
The 22-assertion harness (`tools/sdlc-analyser/__tests__/read-bounding.test.sh`) also exercises
the carve-out fields against a hand-checkable fixture (2 eligible reads, 1 hit, 1 miss ->
`carveOutHitRate: 0.5`) and confirms it can fail: disabling the carve-out computation drops 6
assertions to `FAIL` (verified during this story, tree restored byte-identical after).

### NA-88 D11 — this instrument is self-confirming, not independent evidence

`read-bounding.py` and its fixtures are authored by the same story that ships the `## Bounded
reads` clause this tool measures compliance with. A PASS on `read-bounding.test.sh` proves only
that the tool does what its own author designed — it proves **nothing** about whether any domain
agent obeys the clause, or that any token was actually saved by it. This is a smoke test, never a
gate on agent behaviour. The tool's own `--json` output repeats this note. Gate 3 — a pilot run on
an independent story after this PR merges (`docs/superpowers/plans/NA-90-measurements/pilot-obligation.md`,
written by Phase 2) — is the only evidence about the contract itself.

## `cache-analysis.py`

```text
python3 tools/sdlc-analyser/cache-analysis.py <label> <transcript.jsonl>... [--per-story]
```

Python 3, stdlib only. Reads Claude Code session transcripts (`~/.claude/projects/**/*.jsonl`) and
prints a per-model request / token / cache / `$` table for `<label>`. **Keeps the
`cache_read_input_tokens / total input` hit-rate column — it is the ≥94% guardrail** this story
gates on.

`--per-story` groups the same rows by the story key parsed from each record's `gitBranch`
field (e.g. `feat/NA-86` → `NA-86`; records with no matching branch fall into `unlabeled`) and
prints one report section per story instead of one merged report.

If none of the given transcript paths resolve to a readable file, the script fails with the
resolved path(s) it tried and exits 1 — it never emits a zeroed report that would look like a
real (empty) result.

**Provenance:** ported from `/tmp/cache_an.py` (source math and formatting preserved verbatim).
The spec named `scratchpad/cost8.py` as the source for `--per-story`; that file does not exist in
this repo. `--per-story` was written fresh from its stated contract (a per-story cost roll-up over
the same transcript rows), not ported.

## `rtk-coverage.py`

```text
python3 tools/sdlc-analyser/rtk-coverage.py (--engine | --wrapper <path>) [--corpus-list <file> | --count N] [--json]
```

Replays a transcript corpus through `rtk hook check` and reports how many rewrites the hook
actually performs against how many are available. `--engine` models the upstream first-line defect
(NA-89 F3); `--wrapper <path>` pipes each command through a `PreToolUse` wrapper and counts changed
lines.

Two denominators are always printed. `achievable (raw)` is every line `rtk hook check` would rewrite.
`achievable-permitted` subtracts the rewrites the wrapper is _required_ to decline — lines inside a
heredoc, and lines whose top-level segments resolve to a verification-critical head (ADR 0015).
NA-89's Gate 1 scores `lost-vs-permitted`; `lost-vs-raw` is printed beside it so the guards' cost
stays visible rather than being absorbed into the denominator.

`--corpus-list <file>` pins the corpus to an explicit list of `.jsonl` paths, one per line, resolved
relative to the list file. **Prefer it over `--count`** for any before/after comparison: `--count N`
takes the N most recently modified transcripts, and that window slides between runs, so the two
sides of a delta would not be replaying the same bytes.

### The classification and guard rules (verbatim — an unstated rule makes before/after non-reproducible)

A line is loaded as one **Bash command string** from the transcript: each transcript line is one
JSON record; a `Bash` tool-use is any item of `record["message"]["content"]` (when it is a list)
with `type == "tool_use"` and `name == "Bash"`. The command is `item["input"]["command"]`, taken
verbatim, unsplit — a multi-line command stays one string until `build_report` splits it on `\n`.

**Achievability, per line, first-match-wins:**

```text
line is blank (after strip)             -> not achievable, not counted
rtk hook check -- "<line>" exits 0      -> achievable
ELSE                                    -> not achievable
```

**Guard classification of an achievable line, evaluated per whole command, first-match-wins:**

```text
command contains "<<"                                     -> guardHeredoc  (every achievable line in that command)
ELSE any top-level segment's resolved head ∈ EXCLUDE       -> guardExclude
ELSE                                                       -> counts toward achievable-permitted
```

`achievable-permitted := achievableRaw - guardHeredoc - guardExclude`.

**Segment split (mirrors the wrapper's `line_is_excluded`, G1):** a line is split on `&&`, `||`,
`;`, `|` (in that order, each pass applied to every fragment from the previous pass) into top-level
segments. **Resolved head** of a segment: strip leading `KEY=value` assignment words and leading
runner-prefix words (`pnpm npm yarn bun npx bunx pnpx exec dlx run x`, applied repeatedly), then
take `basename()` of the first remaining word, lower-cased. Empty after stripping → no head, segment
never matches `EXCLUDE`. `EXCLUDE = (tsc, prettier, nx, eslint, lint, vitest, jest, pytest)` —
identical to the wrapper's list (ADR 0015).

**`--engine` mode's `rewrites` count** (models the upstream first-line-only defect, NOT the guard
rules above): a command scores 1 rewrite iff it contains no heredoc, its first line is non-blank,
its first line's resolved head is **not** in `EXCLUDE`, and `rtk hook check` accepts that first
line — 0 otherwise. This deliberately does not use the per-line achievability/guard classification;
it reproduces exactly what the unfixed engine does today.

**`--wrapper <path>` mode's `rewrites` count:** the command is piped through `<path>` as a
`PreToolUsePayload` (`{"tool_name":"Bash","tool_input":{"command":<command>}}`). If the wrapper
emits no stdout, or stdout does not parse to `hookSpecificOutput.updatedInput.command`, the count is 0. Otherwise the count is the number of lines that differ, position-for-position, between the input
and the updated command. **A wrapper whose updated command has a different line count than the
input scores 0, not a best-effort diff** — a wrapper that changes line count has violated its own
contract, and the instrument scores that as a failure rather than silently misaligning the compare.

### NA-88 D11 — this instrument is self-confirming, not independent evidence

`rtk-coverage.py` and the wrapper it scores (`.claude/hooks/rtk-line-scan.sh`) are authored by the
same story. A passing `--wrapper` run over the pinned corpus proves only that the wrapper does what
its own author designed it to do — it does **not** prove the rewritten commands still execute
correctly, that their output remains trustworthy, or that any token was actually saved. Gate 1 (the
`lost-vs-permitted <= 5%` check) is a smoke test and is reported as one, both in this README and in
the tool's own printed output.

**Falsifiability, as the check that this smoke test is not vacuous:** the same instrument, same
pinned corpus, must return two different answers depending on what it is pointed at —
`--engine` (unwrapped, models the shipped defect) returns the ~72–79% loss figure measured for this
story; `--wrapper` (post-fix) returns near-0%. A gate that returned the same number against both
inputs would be evidence about nothing. See Gate 2 in `docs/superpowers/specs/NA-89.md` for the
independent, non-self-confirming confirmation this instrument cannot provide on its own.

## Shared conventions

- `estTokens = floor(bytes / 3.7)`.
- Vendored exclusion: `plugins/sdlc/skills/find-skills/**` and
  `plugins/sdlc/skills/skill-creator/**` are counted in `instruction-inventory.sh` rows but
  excluded from every total — path-based, so it only ever fires when `--root` resolves under
  `plugins/sdlc` (the default).
- None of these tools write to the repo or to `~/.claude/`.
