---
description: Manually-triggered repo-wide scan for AI-config drift, gaps, and config-vs-memory conflicts. Read-only by default; applies a fix only after explicit human confirmation, producing a reviewable diff/PR — never a silent write.
---

`/sdlc:analyze` is **manual only** — there is no scheduling/background trigger. Dispatch the
`ai-enablement-engineer` agent to scan this repo's AI-configuration surface (`CLAUDE.md`,
`AGENT(S).md`, `.agents/**`, `.claude/**`, etc.) plus `plugins/**`/`skills/**` — when the repo has
opted in — for drift, gaps, and config-vs-memory conflicts, and report the findings.

## Default mode — read-only scan + report

The agent should:

1. Read `.claude/project/project-context.md`. **If `ai-enablement-engineer` is not Active there,
   stop** and report: "AI-config management not enabled; run `/sdlc:init` to opt in." Write nothing.
   ("Active" is defined at
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
   `find-skills` suggestions for skill gaps. If nothing was found, report "no drift detected" and
   exit cleanly.

## Apply — only after explicit human confirmation, never auto-apply

After the report, present each proposed fix and ask the user which (if any) to apply. There is
**no inline auto-apply path**.

**Memory conflicts** use the interactive arbitration flow from
`${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#memory-conflict-analysis--resolution`: present the
conflict and the candidate sources of truth; the human picks which side is correct (config vs.
memory, or a specific file) or defers. A deferred conflict is report-only — reset nothing.

For each fix the human confirms, run the
[Apply flow](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#apply-flow):

1. **Scope guard** — resolve effective write-scope again; if any target path falls outside it,
   **refuse and abort**, listing the offending path (AC-5). No writes happen.
2. Apply the scoped edit (Edit/Write) only within resolved write-scope; drive "create a missing
   skill" through `skill-creator`.
3. Commit via the `conventional-commit` skill.
4. **Reviewable diff** — `/sdlc:analyze` runs standalone (not dispatched by `principal-engineer` on
   a story), so branch `chore/ai-config-<slug>` off `main` and raise the PR yourself:
   ```bash
   dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
   # write "$dir/pr-body.md" describing the fix and the finding it resolves
   PR_URL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/raise-pr.sh \
     "chore/ai-config-<slug>" main "chore(ai-config): <fix summary>" "$dir/pr-body.md")
   ```
   If `raise-pr.sh` fails, surface the failure and leave the branch + local commit for manual
   recovery — do not retry silently.
5. Report the diff/PR URL back to the user. Do **not** merge.

## Output

Resolved write-scope (printed first), the drift/gap list + conflict report with proposed fixes,
and `find-skills` suggestions — see
[`#output-shape`](${CLAUDE_PLUGIN_ROOT}/refs/analyze-protocol.md#output-shape) for the exact
per-finding fields (`area` · `kind` · `detail` · `proposed fix` · `target path(s)`, each flagged
`W`/`R`).

## Error handling

| Scenario | Behavior |
| -------- | -------- |
| Repo not opted in (agent not Active in project-context) | No-op — report "AI-config management not enabled; run `/sdlc:init` to opt in." Write nothing. |
| Scan finds no drift/gaps/conflicts | Report "no drift detected" and exit cleanly. |
| Apply attempted without human confirmation | Refuse — confirmation is mandatory (never auto-apply). |
| Apply target outside resolved write-scope | Refuse and abort; print the offending path(s); make no writes (AC-5). |
| Memory conflict with no human decision (deferred) | Report only; reset nothing. |
| Reset targets another agent's memory but not human-arbitrated | Refuse — the cross-agent memory exception applies only to a human-confirmed, reviewable reset. |
| `project-context.md` missing or malformed table | Scan proceeds on the AI-config surface; report the table problem as drift; do not edit project-context (read-only authority). |
| `find-skills` / `skill-creator` unavailable or offline | Degrade gracefully — skip the skill-suggestion step, still emit structural drift; note the skip. |
| `raise-pr.sh` fails during standalone apply | Surface the failure; leave branch + local commit for manual recovery; do not retry silently. |

Optional area/glob to narrow the scan (default: full resolved write-scope):
$ARGUMENTS
