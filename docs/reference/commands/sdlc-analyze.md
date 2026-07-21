---
title: '/sdlc:analyze'
description: 'Manually-triggered repo-wide scan for AI-config drift, gaps, and config-vs-memory conflicts. Read-only by default; applies a fix only after explicit human confirmation, producing a reviewable diff/PR; never a silent write.'
---

# /sdlc:analyze

Manually-triggered repo-wide scan for AI-config drift, gaps, and config-vs-memory conflicts. Read-only by default; applies a fix only after explicit human confirmation, producing a reviewable diff/PR; never a silent write.

---

**Source:** `plugins/sdlc/commands/analyze.md`

`/sdlc:analyze` is **manual only** — there is no scheduling/background trigger. Dispatch the
`ai-enablement-engineer` agent to scan this repo's AI-configuration surface (`CLAUDE.md`,
`AGENT(S).md`, `.agents/**`, `.claude/**`, etc.) plus `plugins/**`/`skills/**` — when the repo has
opted in — for drift, gaps, and config-vs-memory conflicts, and report the findings.

## Default mode — read-only scan + report

The agent should:

1. Read `.claude/project/project-context.md`. **If `ai-enablement-engineer` is not Active there
   (including a missing/malformed table — see
   [Error handling](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#error-handling)), STOP**, report
   per that row. ("Active" is defined at
   [`analyze-protocol.md#ownership-resolution-rules`](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#ownership-resolution-rules):
   row presence in the workspace→agent table is the sole activity signal, no separate flag.)
2. Resolve effective write-scope per
   `${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#ownership-resolution-rules` and print it first.
3. Narrow the scan to `$ARGUMENTS` when an area/glob is given; otherwise scan the full resolved
   scope.
4. Run the scan per `${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#scan-protocol` — the
   [drift/gap checks](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#drift--gap-table) and the
   [memory-conflict analysis](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#memory-conflict-analysis--resolution).
   This step is **read-only** — it writes nothing.
5. Emit the report per
   [`#output-shape`](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#output-shape): the resolved
   write-scope, then the drift/gap list, the conflict report (own section, one entry per conflict:
   the contradictory sources + their exact assertions + file paths), proposed fixes, and any
   `find-skills` suggestions for skill gaps. If a **memory bloat** finding is present (oversized
   agent memory files, or repeated/duplicated learnings), surface it as a **recommendation to run
   `/sdlc:docs distill`** to curate them into ADRs — recommendation only, this scan never runs
   distill itself and gains no new apply path. If nothing was found, report "no drift detected" and
   exit cleanly.

## Apply — only after explicit human confirmation, never auto-apply

After the report, present each proposed fix and ask the user which (if any) to apply. There is
**no inline auto-apply path**.

**Memory conflicts** use the interactive arbitration flow from
`${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#memory-conflict-analysis--resolution`: present the
conflict and the candidate sources of truth; the human picks which side is correct (config vs.
memory, or a specific file) or defers. A deferred conflict is report-only — reset nothing.

For each fix the human confirms, run the
[Apply flow](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#apply-flow) exactly as written there —
scope guard, then (standalone mode) **branch `chore/ai-config-<slug>` off `<BASE-BRANCH>` BEFORE any
edit** (per project-context's Base branch token — never assume `main`), apply, commit, then push +
raise the PR:

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
# write "$dir/pr-body.md" describing the fix and the finding it resolves
PR_URL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/raise-pr.sh \
  "chore/ai-config-<slug>" "<BASE-BRANCH>" "chore(ai-config): <fix summary>" "$dir/pr-body.md")
```

Report the diff/PR URL back to the user. Do **not** merge.

## Output

Resolved write-scope (printed first), the drift/gap list + conflict report with proposed fixes,
and `find-skills` suggestions — see
[`#output-shape`](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#output-shape) for the exact
per-finding fields (`area` · `kind` · `detail` · `proposed fix` · `target path(s)`, each flagged
`W`/`R`).

## Error handling

Canonical table (defined exactly once):
[`analyze-protocol.md#error-handling`](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#error-handling).
Gist: not-Active/unreadable project-context → STOP, report-only; no drift found → report and exit
clean; apply without confirmation or outside write-scope → refuse; `find-skills`/`skill-creator`
offline → degrade gracefully; `find-skills` install/update commands → refuse (surfacing/suggesting
only, see [Skill usage guardrails](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#skill-usage-guardrails)).

Optional area/glob to narrow the scan (default: full resolved write-scope):
$ARGUMENTS
