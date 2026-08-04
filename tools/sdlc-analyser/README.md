# sdlc-analyser

Manual measurement tools for NA-86/NA-87/NA-88/NA-89/NA-90/NA-92/NA-93 (instruction-load
reduction, artifact-encoding reproducibility, duplicate-read classification, rtk rewrite-coverage
replay, read-bounding/carve-out volume, subagent offload placement, loop-decision equivalence).
Read-only: these scripts read the repo and `~/.claude/projects/**/*.jsonl` transcripts, and never
write to either, except `loop-decision.py --enumerate --golden <path>`, which writes only the
golden fixture named by `--golden`. Mostly not wired into CI (`artifact-encoding.test.sh`, shipped
under `plugins/sdlc/scripts/__tests__/`, was the original exception — see `artifact-contract.sh`
below for why that tool stays out of CI; `read-bounding.py`, `context-residency.py`,
`work-placement.py` and `loop-decision.py` below are the other exceptions, CI-wired because each
needs no local binary, only stdlib Python and in-repo fixtures) — run the rest by hand and paste
the output into a PR body.

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
story's own baseline (`docs/superpowers/plans/NA-90-measurements/measurement-block.txt`, which
carries the derived numbers below and survives; the raw `corpus-list.txt` this baseline was run
against is deliberately untracked — it embeds machine-local transcript paths and is excluded by
`.gitignore`'s `docs/superpowers/plans/*-measurements/*corpus*` rule) uses the RECURSIVE corpus
rule** — the corpus list was built from `<project>/*.jsonl` (top-level, 107 files) **union**
`<project>/*/subagents/agent-*.jsonl` (550 files), generated via Python's `glob.glob` rather than
a shell `ls` (a local shell-hook rewrite was observed to append trailing byte-size text to `ls`
output on this machine, corrupting a naive corpus list — `glob.glob` sidesteps it entirely). The
resulting baseline shows `topLevelTranscripts: 107`, `subagentTranscripts: 550`,
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

| Corpus                                                                                                                                                       | `windowedShare` |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------- |
| `all-windowed.jsonl` (synthetic, every read carries `offset`/`limit`)                                                                                        | `1.0`           |
| `all-whole.jsonl` (synthetic, no read carries either)                                                                                                        | `0.0`           |
| real corpus (recursive; derived figure in `NA-90-measurements/measurement-block.txt` — the raw `corpus-list.txt` it was run against is untracked, see above) | `~0.261`        |

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

## `context-residency.py`

```text
python3 tools/sdlc-analyser/context-residency.py <label> (<transcript.jsonl>... | --corpus-list <file>) [--boundary pr-raise|none] [--per-transcript] [--json]
```

Python 3, stdlib only (3.9-compatible), read-only. Measures byte-turn residency of tool results in
a TOP-LEVEL orchestrator transcript, locates the PR-raise boundary, and reports how much resident
context the post-boundary tail inherits — the instrument NA-91's workstream-F guardrail (AC-2,
cache-read ratio >= 94%) is scored against.

**F's population is the TOP-LEVEL orchestrator transcript only** — never a subagent's. Subagent
transcripts (`<session>/subagents/**/agent-*.jsonl`, recursive) are `read-bounding.py`'s and
`duplicate-reads.py`'s population, not this tool's.

### The residency rule (verbatim — an unstated rule makes before/after non-reproducible)

```text
turn        := a record with type == "assistant"; turns are indexed 1..T in file order
T           := assistantTurns, the count of such records in the transcript
result(r)   := an item of record["message"]["content"] with type == "tool_result"
bytes(r)    := len(result text)                     # the bytes actually resident
turn(r)     := the index of the most recent assistant turn at or before r's record
exposure(r) := bytes(r) * (T - turn(r))             # re-billed on every turn after it entered
toolResultExposure := sum of exposure(r) over all r
```

### The boundary rule (verbatim)

```text
boundaryTurn := index of the FIRST assistant turn carrying a tool_use with name == "Bash" whose
                input.command contains "raise-pr.sh" or "gh pr create"; null when absent
inheritedExposure := sum over r with turn(r) <= boundaryTurn of bytes(r) * (T - boundaryTurn)
inheritedShare    := inheritedExposure / toolResultExposure ; 0.0 when boundaryTurn is null
--boundary none -> boundaryTurn forced to null      # the control arm
boundaryTurn is reported only for a SINGLE-transcript run; a pooled corpus reports null and
  transcriptsWithBoundary instead
```

### The corpus rule (verbatim)

```text
origin := subagent   IF the transcript path contains "/subagents/"
origin := orchestrator OTHERWISE
ASSERT corpus.subagentTranscripts == 0 ELSE print a loud one-line WARNING naming the count
       # F's population is the TOP-LEVEL session ONLY; never silently pool the two populations
       # a warning, never exit 1 — a deliberately mixed run is the caller's business to explain
```

### The corpus-completeness rule (verbatim)

```text
missing := a raw path that resolve_paths() could not resolve to a readable file
any missing path -> print a loud one-line WARNING to stderr naming the count and listing
                     every missing path, same register as the subagentTranscripts WARNING
--corpus-list AND missing non-empty -> exit 1  # a pinned corpus list is a deliberate
                     artifact; measuring a silent subset of it is a measurement error, not
                     a convenience
bare positional paths AND missing non-empty -> WARNING only, exit unaffected  # an ad-hoc
                     path list on the command line is already the caller's own choice of
                     what to include; there is no pinned artifact to fall short of
```

A partial corpus that reports clean is worse than one that fails loud — this epic has already
under-captured its own corpus three times (NA-88's 11.7%, NA-90's shallow glob, NA-91's own
missed `workflows/` tier). A dropped file is never silent, and a dropped file from a pinned
`--corpus-list` is a hard failure, not a warning the caller can miss.

**Prefer `--corpus-list` over positional paths for any before/after comparison** — the
`rtk-coverage.py` reasoning: a sliding "most-recent-N" window is not the same bytes on both sides
of a delta. Path lists must be built with Python `pathlib`/`glob`, never parsed `ls` — the local
rtk shell hook size-annotates `ls` output, silently corrupting a naive corpus list.

**`--json` emits the full `ContextResidencyReport` contract**: `label`, `topLevelTranscripts`,
`subagentTranscripts`, `assistantTurns`, `toolResultExposure`, `boundaryTurn`, `boundaryCommand`,
`transcriptsWithBoundary`, `inheritedExposure`, `inheritedShare`, `cacheReadRatio` (the AC-2
guardrail — `cache_read / (cache_read + cache_creation + input)`), `skippedLines`. Without
`--json`, a human-readable table carrying the same numbers. `--per-transcript` emits one report
per transcript (blank-line separated) instead of one pooled report — this is the shape the
per-session median in NA-91's measurement block is computed from.

**Error handling:** no given path resolves to a readable file -> every path tried is printed to
stderr, exit 1 (never a zeroed report that reads like a real empty result). A partial miss (some
paths resolve, some don't) -> loud stderr WARNING naming the count and every dropped path;
`--corpus-list` additionally exits 1, bare positional paths exit 0 (see the corpus-completeness
rule above). Unparseable transcript line -> skipped, `skippedLines += 1`, exit 0 (a truncated
last line is normal in a live transcript). A transcript path containing `/subagents/` -> counted
in `subagentTranscripts` and a loud WARNING to stderr, never silently pooled with the top-level
population. Invalid `--boundary` value -> error naming the flag and the value, exit 2.

### Gate 2 — falsifiability

| Corpus                                                                | `inheritedShare` |
| --------------------------------------------------------------------- | ---------------- |
| `no-boundary.jsonl` (synthetic, no PR raise)                          | `0.0`            |
| `partial.jsonl` (synthetic, half the exposure pre-boundary)           | `0.5`            |
| `full-inherit.jsonl` (synthetic, every result enters at the boundary) | `1.0`            |

A tool that returned the same number against all three would be incapable of measuring anything.
The 28-assertion harness (`tools/sdlc-analyser/__tests__/context-residency.test.sh`) exercises
these three fixtures plus the `--boundary none` control arm, the corpus partition, the subagent
WARNING, the corpus-completeness WARNING/exit-code pair (both the `--corpus-list` and bare-path
variants), the docstring's stated `cacheReadRatio` formula, and every error-handling row in the
table above. Falsifiability was proven during this story by perturbing seven assertions in turn
(boundary-marker detection, the exposure formula, the cache-read numerator, the skipped-line
counter, the corpus-completeness WARNING print, the `--corpus-list` non-zero exit, and the
docstring's `cacheReadRatio` formula line) — each perturbation flipped the expected assertions to
FAIL, and the tree was restored byte-identical (`git checkout --`) and re-verified green after
each.

### NA-88 D11 — this instrument is self-confirming, not independent evidence

`context-residency.py` and its fixtures are authored by the same story that ships the
session-boundary contract this tool measures. A PASS on `context-residency.test.sh` proves only
that the tool does what its own author designed — it proves **nothing** about whether any real
session obeys the boundary, or that any token was actually saved by it. This is a smoke test,
never a gate on session behaviour. Gate 3 — a pilot run on an independent story after the
session-boundary PR merges and the sdlc plugin is released — is the only evidence about the
contract itself.

## `work-placement.py`

```text
python3 tools/sdlc-analyser/work-placement.py <label> (<transcript.jsonl>... | --corpus-list <file>) [--json]
```

Python 3, stdlib only (3.9-compatible), read-only. Measures, per unit of work (G1/G2/G3/P1),
what share of that unit's direct-execution tool-result bytes landed in a subagent rather
than the orchestrator, and whether the unit's dispatch return exceeded its stated
round-trip cap — the instrument NA-92's workstream-G pilot gate (AC-2/AC-3/AC-4) is
scored against. Unit `P1` (NA-81 Phase 4) extends this same instrument to score the
`plan-slice.sh` contract's named successor pilot (see "The unit signatures" and "The `P1`
overlap and double-count caveats" below).

### The three-tier corpus rule (verbatim)

```text
project := ~/.claude/projects/<encoded-repo-path>
T1 top-level := <project>/*.jsonl
T2 subagent  := <project>/*/subagents/agent-*.jsonl
T3 wf agent  := <project>/*/subagents/workflows/wf_*/agent-*.jsonl
```

Measured on this repo's corpus (NA-92): T1 **107**, T2 **557**, T3 **890** — T3 alone is
61.5% of all subagent transcripts and is invisible to any non-recursive glob (NA-90's
shipped bug). Every corpus-list / positional entry is treated as a **root**: a directory
root expands to `root.glob("*.jsonl")` for T1 (non-recursive, direct children only) plus
`root.rglob("agent-*.jsonl")` for T2+T3 (recursive — **required**); a `.jsonl` file entry
is used as-is, tiered by `origin_of(path)` (`"subagent"` if `/subagents/` appears in the
path, `"orchestrator"` otherwise — same convention as `read-bounding.py` and
`context-residency.py`). Path lists are built with Python `pathlib`, never parsed `ls` —
the local rtk shell hook rewrites and size-annotates `ls` output, silently corrupting a
naive corpus list.

### The unit signatures (verbatim, echoed into `units[].signature`)

```text
G1 qa-gate-run      := Bash matching nx run-many|affected|run … test|lint|typecheck|build,
                        pnpm test|lint, vitest, jest; OR any input naming qa-gate-runner.md
G2 ac-verification  := input naming docs/superpowers/plans/, a `git log <range> --oneline`,
                        verification-before-completion, or ac-verification.md
G3 docs-sync-gate   := input naming docs-manifest.md, docs-pipeline, or docs-sync-gate.sh
P1 plan-slice       := any input naming plan-slice.sh or docs/superpowers/plans/
```

Attribution counts only **direct-execution** tool results — `Bash`, `Read`, `Grep`,
`Glob`. `Agent` and `SendMessage` returns are excluded from this count on purpose: that
traffic is already inside a subagent, and counting it would inflate G's own claim.

### The `P1` overlap and double-count caveats

**Overlap with `G2`, intended, not silently resolved.** `P1`'s signature partly overlaps
`G2 ac-verification` — both name `docs/superpowers/plans/`. `UNITS` is scanned in
declared order (`G1`, `G2`, `G3`, `P1`) and the per-call match loop breaks on the first
hit, so a call whose text satisfies both `G2` and `P1` (a literal
`docs/superpowers/plans/<file>.md` path passed directly rather than via a shell variable)
attributes to `G2`. `P1` fires on its own only when the call names `plan-slice.sh` without
independently satisfying one of `G2`'s own patterns — exactly the real dispatch shape
(`bash .../plan-slice.sh "$PLAN" phase <agent>`, where `$PLAN` is unexpanded in the
recorded command text). A second instrument was rejected for this reason: it would
duplicate the three-tier corpus rule a third time to measure a signature that already
shares `G2`'s population.

**The double-count warning (verbatim — NA-93's own shipped bug).** When measuring the
named successor pilot's real transcripts by hand, each probe event is stored **twice per
JSONL record**: once in `message.content` (a `tool_result` item — the only place
`work-placement.py` reads from) and again in a sibling `toolUseResult.stdout` field this
script never touches. Counting both inflated NA-93's own baseline from 97 to a reported 186. **Count one, not both.**

### The placement and return-cap rules (verbatim)

```text
orchestratorBytes(unit) := sum of matched direct-execution result bytes, origin == orchestrator
subagentBytes(unit)     := sum of matched direct-execution result bytes, origin == subagent
subagentShare(unit)     := subagentBytes / (orchestratorBytes + subagentBytes)
                            null WHEN the unit never fired (no matched call at all) — never
                            0.0, which would be indistinguishable from "fired entirely at
                            top level"

returnBytes(unit)       := bytes the unit's dispatch return contributed at the top level —
                            for G1/G2, the tool_result of an `Agent` call whose joined input
                            text names that unit's ref (qa-gate-runner.md / ac-verification.md);
                            for G3 and P1, the tool_result of a `Bash` call naming
                            docs-sync-gate.sh / plan-slice.sh respectively (both are scripts,
                            not dispatches — the same call is both execution and return)
returnCapBytes          := 2000 (G1) / 4000 (G2) / 200 (G3) / 200 (P1) — stated caps, never derived
returnCapExceeded(unit) := returnBytes(unit) > returnCapBytes(unit)     # the round-trip detector
```

`toolResultBytes` / `toolResultExposure` reuse `context-residency.py`'s residency rule
(`exposure(r) := bytes(r) * (T - turn(r))`, per-transcript turn indexing) but pooled over
the **whole resolved corpus, both tiers** — unlike `context-residency.py`'s top-level-only
population, because this instrument's job spans both. `cacheReadRatio` is the same
`cacheRead / (cacheRead + cacheCreation + input)` formula as `context-residency.py`'s AC-2
guardrail, pooled the same way, included here as a convenience cross-check.

**`--json` emits the full contract**: `label`, `corpus` (`topLevelTranscripts`,
`subagentTranscripts`), `units[]` (`id`, `signature`, `orchestratorBytes`,
`subagentBytes`, `subagentShare`, `returnBytes`, `returnCapBytes`, `returnCapExceeded`),
`toolResultBytes`, `toolResultExposure`, `cacheReadRatio`, `skippedLines`,
`missingCorpusPaths`. Without `--json`, a human-readable table.

**Error handling.** No resolved transcript file at all -> every path/root tried is
printed to stderr, exit 1. A partial corpus-list miss -> loud stderr WARNING naming the
count and every dropped root; `--corpus-list` exits 1, bare positional paths exit 0
(same corpus-completeness rule as `context-residency.py`). Unparseable transcript line ->
skipped, `skippedLines += 1`, exit 0. **0 T3 (`workflows/wf_*`) transcripts resolved
against a real corpus** -> loud stderr WARNING naming the count, same register as
`read-bounding.py`'s non-recursive-glob warning — this is the exact defect (NA-90's
shipped bug) the three-tier corpus rule exists to catch.

### Falsifiability harness

`tools/sdlc-analyser/__tests__/work-placement.test.sh` (26 assertions, CI-wired) proves
`subagentShare` reaches 0.0, 0.5 **and** 1.0 and `returnCapExceeded` reaches both `true`
and `false`, over seven hand-authored fixture corpora
(`__tests__/fixtures/work-placement/`). Every per-unit field is read via a `python3` JSON
extraction, never a whole-blob substring grep — a substring check on `"subagentShare":
1.0` stays green as long as **any** unit reports 1.0, so it cannot catch a regression
isolated to one unit. This was caught live while proving F-11 (swap the corpus's `rglob`
for a non-recursive `glob("*/subagents/agent-*.jsonl")`): G1/G2 still resolved via the
shallower one-level pattern, so the original substring assertion stayed green even though
G3 — whose fixture signature lives **only** in the `workflows/wf_x/` tier — had silently
dropped to `null`. The rewritten per-unit assertion catches it. F-12 (hard-coding
`returnCapExceeded` to `False`) and F-13 (dropping the `skippedLines` increment) and F-14
(deleting the T3-completeness WARNING branch) were each proven to flip their owning
assertion to FAIL and restored byte-identical (`git checkout --` / a saved copy) before
this story shipped.

**NA-81 Phase 4 adds `P1`'s two fixtures and proves each falsifiable the same way.**
`p1-only.jsonl` (a Bash call naming `plan-slice.sh` with `$PLAN` unexpanded, so it does
not also satisfy `G2`'s pattern) proves `P1` fires in isolation. Its three `G1`/`G2`/`G3`
"never fired" assertions hold unconditionally (they assert on units that never match this
fixture regardless of `P1`); its `P1 orchestratorBytes non-zero` assertion is the one that
depends on `match_p1()` — disabling `match_p1()` flips it to FAIL, restored byte-identical.
`double-count.jsonl` (one record carrying the identical probe text in both
`message.content` and a sibling `toolUseResult.stdout`) proves the double-count rule
holds — adding `toolUseResult.stdout` bytes into the count doubles `P1`'s
`orchestratorBytes` from 36 to 72, flipping its owning assertion to FAIL, restored
byte-identical.

### NA-88 D11 — this instrument is self-confirming, not independent evidence

`work-placement.py` and its fixtures are authored by the same story that ships the
offload contract (refs/qa-gate-runner.md, refs/ac-verification.md,
scripts/docs-sync-gate.sh) this tool measures compliance with. A PASS on
`work-placement.test.sh` proves only that the tool does what its own author designed — it
proves **nothing** about whether any real session obeys the offload contract, or that any
byte was actually relocated. This is a smoke test, never a gate on agent behaviour. The
pilot (`docs/superpowers/plans/NA-92-measurements/pilot-obligation.md`, a story NA-92
does not author) is the only evidence about the contract itself. **Unit `P1` carries the
identical caveat for NA-81's `plan-slice.sh` contract**: this run executed the pre-NA-81
dispatch contract (the script did not exist yet to be called), so a `P1` PASS here proves
only that the tool measures its own designed signature correctly — it proves nothing about
whether any real dispatch calls `plan-slice.sh`. The named successor pilot (the first
`full`-triaged story run end-to-end through `/sdlc:auto` after NA-81 merges and the sdlc
plugin is released) is the only evidence about that.

## `loop-decision.py`

```text
python3 tools/sdlc-analyser/loop-decision.py --extract <loop.md> <loop-modes.md> [--json]
python3 tools/sdlc-analyser/loop-decision.py --enumerate --golden <path> [--extract-from <loop.md> <loop-modes.md>] [--json]
python3 tools/sdlc-analyser/loop-decision.py --replay <label> (<transcript.jsonl>... | --corpus-list <file>) [--json]
```

Python 3, stdlib only (3.9-compatible). NA-93 (workstream H) moves the `sdlc:loop`
probe-and-decide body — `commands/loop.md` Step 3+4 and `refs/loop-modes.md` CI-1+CI-2 — into a
deterministic script, `plugins/sdlc/scripts/loop-decide.sh`. This tool parses the two markdown
decision tables **per field** (never as a whole-cell string match), enumerates the domain those
tables define, pins the pre-change extraction as a golden fixture, and replays the real corpus
against that golden.

### The decision domain (verbatim — only the 0/1/>1 distinction is load-bearing)

```text
copilot    := rh∈{0,1} × cr∈{0,1} × cp∈{0,1} × ra∈{0,1} × un∈{0,1,2} × pend∈{0,1,2}
              × fail∈{0,1,2} × pass∈{0,1,2}                      = 2^4 · 3^4 = 1,296
in-session := rh∈{0,1} × rc∈{0,1,'-'} × un∈{0,1,2} × pend∈{0,1,2} × fail∈{0,1,2} = 162
total      := 1,458 cases
```

Field names are exactly what `pr-loop-status.sh:130`'s `loop-status:` line and the in-session
CI-1 progress print use: copilot (8) `copilot-reviewed-head`, `copilot-changes-requested`,
`copilot-pending`, `unresolved-copilot`, `checks-pending`, `checks-failing`, `checks-passing`,
`copilot-reviewed-any`; in-session (5) `reviewed-head`, `review-clean`, `unresolved`,
`checks-pending`, `checks-failing`.

`review-clean='-'` is a **legitimate value, not a parse failure** — CI-1 sets it when the review
marker is absent or half-written. No rule in the in-session table ever compares `review-clean` to
anything but the literals `0`/`1`, so the generic comparator already does the right thing without
a special case: `'-'` never equals `0` or `1`, so every rule testing `review-clean` fails for it,
and `(reviewed-head=1, review-clean='-')` falls through to the catch-all `CI-f` exactly as
required. Treating any non-numeric field as unresolvable instead would collapse 54 of the 162
in-session cases and make the equivalence gate measure nothing (this epic's F-11).

### The extraction rule (verbatim — per field, never a whole-cell match)

```text
condition cell := a `&&`-joined list of comparisons over the named fields
comparison     := <field> <op> <literal>            # op ⊆ {==, !=, >, <, >=, <=}
`||` inside a cell (rule 3) -> a disjunction group; preserved, never flattened
_(catch-all)_ -> conditions := []                    # rules 7 and CI-f
```

The Rule → DECISION mapping is a fixed 16-row table taken verbatim from the plan, not inferred
from either table's prose column. `--extract` asserts the copilot table yields exactly 8 rules
(1, 2a, 2b, 3, 4, 5, 6, 7) and the in-session table exactly 7 (CI-a..CI-f); a wrong count means
the extractor is misparsing and the tool exits non-zero rather than emitting a golden.

### The golden's provenance (amendment A3)

`--enumerate --golden <path>` writes `sourceSha` (`git rev-parse HEAD`, captured by the tool
itself) and `sourceBytes` (measured by the tool from the files it just read, never passed in)
alongside `domain` and all 1,458 `cases[]`. At `433120d` (the pre-H sha) `sourceBytes` is
`{"plugins/sdlc/commands/loop.md": 17544, "plugins/sdlc/refs/loop-modes.md": 18851}` — a
regenerated golden after Phase 2's rewrite would carry different bytes at a different sha, and
`plugins/sdlc/scripts/__tests__/loop-decide.test.sh` asserts `git show <sourceSha>:loop.md | wc -c
== 17544` so the mistake is mechanically caught, not merely discouraged (NA-88 D11 — the golden is
the one artifact in this story extracted by a different phase from text its own author did not
write).

### Why `--replay` classifies against the golden, not a fresh parse

By the time Phase 3 runs `--replay` against the real corpus, Phase 2 has already replaced both
markdown tables with a script call — there is no table left to parse. `--replay` therefore loads
the **committed golden**'s `cases[]` as a direct `(bucketed fields) -> rule` lookup and classifies
every real `loop-status:` snapshot against it. `refs/loop-modes.md` CI-1 calls `pr-loop-status.sh`
"only for its checks-\* fields", but that script always prints the full 8-field `loop-status:` line
regardless of caller, so every real snapshot in this repo's corpus is Copilot-shaped even though
`Review agent: claude-inline` is configured — `--replay` only ever classifies the 8-field shape.

```text
bucket(v) := v   IF v ∈ {0, 1}
bucket(v) := 2   OTHERWISE   # collapses any raw count >= 2 (e.g. un=3, un=4) into the domain's un=2
```

The three-tier corpus rule is identical to `work-placement.py`'s (T1 `*.jsonl`, T2
`*/subagents/agent-*.jsonl`, T3 `*/subagents/workflows/wf_*/agent-*.jsonl`, `rglob` required for
T2+T3). `observed.rulesWithZeroEvidence` lists every one of the 8 copilot rule ids the resolved
corpus never selected — at the real 186-snapshot / 9-distinct-tuple corpus this is exactly
`["1", "5", "6", "7"]`. **This assertion exists so a 1,458/1,458 enumeration pass can never be read
as production coverage** — enumeration proves the script matches the table; it does not prove the
table was ever right for the four unexercised rules.

**`--json` emits**: `label`, `corpus` (`topLevelTranscripts`, `subagentTranscripts`), `domain`
(`copilotCases`/`inSessionCases`/`totalCases`), `observed` (`snapshots`, `distinct`, `byRule`,
`rulesWithZeroEvidence`), `skippedLines`, `missingCorpusPaths`. Error handling mirrors
`work-placement.py`: no resolved transcript at all → every path/root tried, exit 1; a partial
`--corpus-list` miss → loud stderr WARNING, `--corpus-list` exits 1; an unparseable transcript line
→ skipped, `skippedLines += 1`; 0 T3 transcripts resolved → loud stderr WARNING naming the count.

### Falsifiability harness

`tools/sdlc-analyser/__tests__/loop-decision.test.sh` (11 assertions, CI-wired) proves: `--extract`
reads per field (`fixtures/loop-decision/tables-perturbed/` widens rule 4 by deleting its
`checks-pending == 0` clause — the clean and perturbed extractions of rule 4 must differ); the
domain is exactly 1,296/162/1,458; rule selection is invariant in `checks-passing`; `--replay`
reaches the T3 tier over a three-tier fixture corpus (`observed/root.jsonl` T1,
`observed/root/subagents/agent-a.jsonl` T2, `observed/root/subagents/workflows/wf_x/agent-b.jsonl`
T3 — the T3 file carries a raw tuple, `unresolved-copilot=4`, that appears in no other tier, so a
non-recursive corpus build would under-count `observed.distinct` and `observed.snapshots`, exactly
NA-90's shipped bug); `rulesWithZeroEvidence` reports the fixture's own known-unexercised rules;
and `skippedLines` counts the fixture's one deliberately-malformed JSONL line. All six
falsifiability assertions (F-1 through F-6) were proven to flip to FAIL under their named
perturbation and restored byte-identical (`git checkout --`) before this story shipped.

### NA-88 D11 — this instrument is self-confirming, not independent evidence

`loop-decision.py` and its fixtures are authored by the same story that ships
`plugins/sdlc/scripts/loop-decide.sh`, the script it later validates. A PASS on
`loop-decision.test.sh` proves only that the tool does what its own author designed — it proves
**nothing** about whether rules 1, 5, 6 or 7 are correct, because no real PR has ever exercised
them (`observed.rulesWithZeroEvidence` exists precisely to keep that limitation visible on every
run). The one place this story escapes D11 is the golden itself: it is extracted by
`platform-engineer` in Phase 1, before `ai-enablement-engineer` rewrites either table in Phase 2 —
an extract of text its own author did not write.

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
