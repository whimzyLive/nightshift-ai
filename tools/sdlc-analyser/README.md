# sdlc-analyser

Manual measurement tools for NA-86 (instruction-load reduction). Read-only: these scripts read
the repo and `~/.claude/projects/**/*.jsonl` transcripts, and never write to either. Not wired
into CI — run them by hand and paste the output into a PR body.

## `instruction-inventory.sh`

```text
bash tools/sdlc-analyser/instruction-inventory.sh [--padding] [--base <git-ref>] [--json]
```

Scans every file under `plugins/sdlc/**/*.md`. One row per file: `path`, `bytes`, `estTokens`,
`category` (`command | agent | ref | skill | script | other`, derived from the file's top-level
directory under `plugins/sdlc/`), `vendored` (`true` for `plugins/sdlc/skills/find-skills/**` and
`plugins/sdlc/skills/skill-creator/**`). Vendored rows are excluded from every total.

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
been.

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

## Shared conventions

- `estTokens = floor(bytes / 3.7)`.
- Vendored exclusion: `plugins/sdlc/skills/find-skills/**` and
  `plugins/sdlc/skills/skill-creator/**` are counted in `instruction-inventory.sh` rows but
  excluded from every total.
- None of these tools write to the repo or to `~/.claude/`.
