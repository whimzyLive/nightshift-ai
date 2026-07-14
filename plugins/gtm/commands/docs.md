---
description: Audits this repo's existing documentation (README + docs/**) against marketingskills ai-seo + content-strategy guidance and opens the fewest improvement PRs the scope allows — each citing the audit finding it fixes. A clean audit or --dry-run opens nothing. Requires /gtm:init context.
---

Audit this repository's existing documentation. `/gtm:docs` is a **thin orchestrator** — it holds
no audit logic itself. It dispatches `docs-auditor` to enumerate the corpus, audit it against the
`ai-seo` + `content-strategy` rubric, group findings, and open the PRs; this command's job is the
precondition check, config resolution, the idempotency guard, dispatch, and the report.

This command receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness — use it directly, per the
`commands/init.md` convention. Commands need no plugin-root resolver block — that mechanism is for
agents only.

## Flags

- `--dry-run` (optional) — run the full audit and report findings inline, but open **no** PRs.
- `--paths <glob[,glob...]>` (optional) — override the configured `Docs audit paths` for this run
  only. Does not persist to `marketing-context.md`.
- `--max-prs <n>` (optional, default `5`) — ceiling on PRs opened this run. Never a target — the
  agent opens the fewest PRs the scope allows; any excess finding groups are reported as deferred.

## Step 1 — Precondition check

Verify both context files exist and are non-empty:

```bash
[ -s ".claude/project/marketing-context.md" ] && [ -s ".agents/product-marketing.md" ] \
  && echo "PRECONDITION=ok" || echo "PRECONDITION=missing"
```

If either file is missing or empty, **STOP** before dispatching anything, with exactly:

> Run `/gtm:init` first — marketing context is not set up.

`ai-seo` and `content-strategy` both need product + audience context to judge keyword-intent and
positioning-consistency findings, so this guard mirrors `/gtm:site`'s precondition exactly.

**Then ensure the agent's plugin-root marker exists.** The dispatched `docs-auditor` resolves
`${CLAUDE_PLUGIN_ROOT}` via `.claude/.gtm-plugin-root`, a gitignored per-machine cache that is
routinely absent on a fresh clone. This command holds the native value, so write the marker before
dispatching:

```bash
[ -s ".claude/.gtm-plugin-root" ] || printf '%s\n' "${CLAUDE_PLUGIN_ROOT}" > .claude/.gtm-plugin-root
```

## Step 2 — Resolve the audit corpus

Read `## Docs audit` from `.claude/project/marketing-context.md`:

| Field                 | Default when absent from config                                             |
| --------------------- | --------------------------------------------------------------------------- |
| `Docs audit paths`    | `README.md`, `docs/**/*.md`, `docs/**/*.mdx`                                |
| `Docs audit excludes` | `docs/superpowers/**`, `docs/features/**`, `docs/gtm/**`, `**/CHANGELOG.md` |

If the `## Docs audit` block is absent (the config predates this story), fall back to the
defaults above and note the fallback in the step-5 report — do not treat this as an error.

If `--paths` was passed on this invocation, it **replaces** the resolved `Docs audit paths` for
this run only (the excludes still apply; `--paths` never overrides excludes).

## Step 3 — Enumerate existing open audit PRs (idempotency guard input)

List every currently-open PR whose head branch is namespaced under `gtm/docs-audit/*`, and pull
the finding IDs each one's body already claims — a re-run must not duplicate a PR for a finding
group that's already under review. Do this with a **single** `gh pr list` call — never a
`gh pr view` per PR (an N+1 pattern that costs one extra API round trip per already-open audit
PR for no benefit, since `gh pr list --json` already exposes `body`):

```bash
gh pr list --search "head:gtm/docs-audit/" --state open \
  --json headRefName,url,body 2>&1 | jq -c '.[]'
```

`head:` in `--search` is a substring match on the ref (unlike `--head`'s exact match), which is
exactly what a `gtm/docs-audit/` prefix probe needs. `jq -c '.[]'` (real `jq`, run locally on the
already-fetched JSON — not another `gh` call) prints one compact, single-line JSON object per PR,
which is safe to loop over even though `body` itself is multi-line text (compact mode escapes the
embedded newlines, so each PR still occupies exactly one line of the loop's input).

For each PR line, extract its finding IDs from `body`. **Scope the extraction to the "## Docs
audit findings addressed" section only** — the `docs-auditor` PR-body convention also appends a
`## Summary` section afterward, and that section's own bullets may start with backtick-quoted
kebab-case tokens too (e.g. a category or group slug); grepping the whole body would harvest
those as spurious finding IDs and cause a later run to silently treat genuinely new findings as
already covered. Each real finding is a line ``- `<findingId>` (`<rubricRef>`): <summary>``, so
the first backtick-quoted token on a `- ` line **within that section** is the finding ID:

```bash
while IFS= read -r pr; do
  branch="$(printf '%s' "$pr" | jq -r '.headRefName')"
  url="$(printf '%s' "$pr" | jq -r '.url')"
  ids="$(printf '%s' "$pr" | jq -r '.body' \
    | sed -n '/^## Docs audit findings addressed/,/^## /p' \
    | grep -oE '^- `[a-z0-9][a-z0-9-]*`' | sed -E 's/^- `([^`]+)`$/\1/')"
  printf 'PR\t%s\t%s\t%s\n' "$branch" "$url" "$ids"
done
```

(`sed -n '/start/,/end/p'` prints from the findings heading up to — and including — the next
`## ` heading; if the findings section were ever the last thing in the body, with no following
heading, the range simply prints to end of input, which still scopes correctly.)

Build the existing-PR set — `{ branch, url, findingIds }` per PR — to pass into the dispatch
below. An empty result (no open `gtm/docs-audit/*` PRs) is not an error; pass an empty set.

## Step 4 — Dispatch `docs-auditor`

Dispatch with:

- The resolved include globs (step 2, config or `--paths`) and exclude globs.
- `--dry-run` state (boolean).
- `--max-prs` (this run's value or the default `5`).
- The existing-open-PR set from step 3.

Wait for the agent's inline `DocsAuditResult` return (findings, prs, deferredGroups,
corpusFilesAudited) plus its prose summary, skipped-group notes, and any degraded-state flags.

## Step 5 — Report

Return:

1. **Files audited**: `corpusFilesAudited` from the result, plus the resolved paths/excludes used
   (and whether they came from config or the documented fallback — step 2's note).
2. **Findings**, grouped by `category` with `severity` — or, on a clean corpus, an explicit
   statement that no findings were produced.
3. **PRs opened**: each `DocsAuditPr` URL mapped to the `findingIds` it addresses — or, when
   `prs` is empty, an explicit **"no PRs opened"** line stating the reason (clean audit,
   `--dry-run`, or zero-file corpus).
4. **Deferred groups**: `deferredGroups` slugs, if any (finding groups beyond `--max-prs`).
5. **Skipped-as-already-open findings/groups**: from the agent's prose notes (its idempotency
   guard — a finding-level match in its step 3, or a branch-slug match in its step 4), with the
   existing PR URLs involved.
6. **Degraded state**: any skill (`ai-seo` / `content-strategy`) that failed to load, the step-2
   config fallback (if used), or a `git`/`gh` error that stopped the PR loop.

## Error handling

Command-level scenarios only — everything that happens once `docs-auditor` is dispatched (clean
audit, `--dry-run`, zero-file corpus, the two idempotency-guard layers, `--max-prs` overflow,
git/gh failures, a missing marketingskills skill) is the agent's own error handling, not
restated here: see `docs-auditor.md`'s **Error Handling** table, which this command's step-5
report surfaces verbatim from the agent's return.

| Scenario                                                               | Behaviour                                                                      | Outcome            |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------ |
| `marketing-context.md` or `.agents/product-marketing.md` missing/empty | STOP at step 1 with the `/gtm:init` guidance                                   | No dispatch, no PR |
| `.claude/.gtm-plugin-root` missing                                     | Not an error — step 1 writes it before dispatch (gitignored per-machine cache) | Proceeds           |
| `## Docs audit` block absent from `marketing-context.md`               | Fall back to documented defaults (step 2); note the fallback in the report     | Proceeds, reported |
