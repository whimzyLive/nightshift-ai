# sdlc-analyser

Manual measurement tools for NA-86/NA-87 (instruction-load reduction, artifact-encoding
reproducibility). Read-only: these scripts read the repo and `~/.claude/projects/**/*.jsonl`
transcripts, and never write to either. Not wired into CI (`artifact-encoding.test.sh`, shipped
under `plugins/sdlc/scripts/__tests__/`, is the one exception — see `artifact-contract.sh` below
for why this tool set stays out of CI) — run them by hand and paste the output into a PR body.

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
**positional and order-sensitive**: item _i_ of the template's ordered item list is compared against
item _i_ of the artifact's ordered item list (a direct zip, not a search/realignment). Item _i_
matches when `kind` is equal **and** the values match, where a template value containing a
placeholder — `[...]`, `<...>`, or the literal `NNNN` — matches **any** artifact value of the same
kind at that position. A template item with no artifact counterpart at its position is **missing**.

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
  excluded from every total — path-based, so it only ever fires when `--root` resolves under
  `plugins/sdlc` (the default).
- None of these tools write to the repo or to `~/.claude/`.
