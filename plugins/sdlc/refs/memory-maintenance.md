# Memory maintenance op

Executed by `ai-enablement-engineer`. Entered from the `memory-gc-overdue` analyze finding's apply
path (`refs/analyze-protocol.md`) or by explicit founder instruction — never on a schedule, never
auto-triggered.

`<memory-root>` := the path printed by `bash ${CLAUDE_PLUGIN_ROOT}/scripts/memory-root.sh --print-root`.

## One-time corpus migration (`migrate-memory-root.sh`)

`${CLAUDE_PLUGIN_ROOT}/scripts/migrate-memory-root.sh` is a **separate, one-shot** tool from the
five ongoing ops below — it is what gets a repo's in-repo `.claude/memories/{agents,reviews}`
corpus INTO `<memory-root>` in the first place (NA-102), a prerequisite that has to happen exactly
once per repo before any of the ongoing ops below have an external root to operate on. It is
founder-run, not agent-dispatched, and not wired into any command or CI step — invoke it directly:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/migrate-memory-root.sh --dry-run   # ALWAYS first: read the output, mutates nothing
bash ${CLAUDE_PLUGIN_ROOT}/scripts/migrate-memory-root.sh             # the real run, once the dry-run output looks right
```

It copies the tracked corpus to `<memory-root>`, verifies every file (count AND checksum) before
touching anything, then `git rm --cached`s, deletes the working copies, and commits — refusing
outright (never guessing, never partially applying) on a non-empty destination without `--force`,
a partial or inconsistent corpus, a symlinked entry, or a destination inside the repo itself. Full
contract and every refusal condition are documented in the script's own header comment; `-h`
documents `--force`'s exact (narrow) scope. Idempotent — once migrated, a re-run is a no-op.

**Always founder-gated, always a reviewable PR, never a silent write.** This op has no auto-apply
path: every proposed change (a demotion, a deletion, a promotion) is presented to the founder and
applied only after explicit confirmation, exactly like every other apply flow in this plugin
(`refs/analyze-protocol.md#apply-flow`). A proposed deletion without founder confirmation is
refused, not queued.

## The five operations

| Op | Rule |
| --- | --- |
| Capture promotion | For each capture the `/sdlc:docs distill` gate marked `memory`: normalise `promote-target` EXACTLY ONCE into `rel` (`promote-target` with a leading `.claude/memories/` stripped) and use that one `rel` everywhere. Write it to `<memory-root>/$rel` with the capture-only fields stripped and `status: active` set (rule kind), renaming `<STORY-KEY>--<rule-id>.md` → `<rule-id>.md`. For the NA-101 shim's duration take the merge base from BOTH roots using the same `$rel`: when `<memory-root>/$rel` is absent but `<repo-root>/.claude/memories/$rel` exists, read the legacy file as the merge base so `uses` and `evidence` accumulate, then write the merged result to `<memory-root>/$rel`. NEVER substitute the raw `promote-target` into the legacy path — for a legacy-form capture that builds `<repo-root>/.claude/memories/.claude/memories/…`, which never exists, and the "first root wins" rule would then hide the richer legacy copy behind a counter-reset file. If the target exists, ONLY `uses := existing.uses + capture.uses` and the union of `evidence` change — `rule`, `agent`, and `trigger` stay exactly the existing file's values (a counter-only capture legitimately carries an empty `agent`; never let it clobber an existing `agents/shared/` rule's multi-name audience). Then delete the promoted capture. Never re-authors the `rule` line, never reshapes the schema. |
| Decay / demotion | `status: active` + `uses: 0` + newest `evidence` older than the retention window → propose `status: deprecated`. Already `deprecated` and one further window elapsed → propose deletion. |
| Review-file GC | Delete a review file when (a) every id in its `## Rules written` is now `status: promoted`, or (b) it is an `issue_count: 0` marker older than the retention window, or (c) it wrote no rules and is older than the retention window, or (d) it is a capture (either kind) older than the retention window — the same founder gate applies; "unpromoted" and "stale" are indistinguishable from the outside, which is why this sweep is never automatic. |
| ADR-candidate nomination | Nominate every rule with `uses >= 3` OR `agent` length >= 2; emit the candidate list (id, rule, evidence, uses) and hand it to `knowledge-engineer` for `/sdlc:docs distill`. **Nomination never writes an ADR.** |
| T1 deletion-on-promotion | When distill lands an ADR that supersedes a rule, set the rule `status: promoted`, then delete it in the maintenance PR. Promotion is one-way and terminal — a promoted rule is deleted, never revived. |

Run the five ops in this order when the maintenance op is invoked as a whole: **capture promotion →
decay/demotion → review-file GC → nomination → T1 deletion**. Decay/demotion and review-file GC are
independent of each other; nomination reads the post-decay rule set; T1 deletion runs last since it
depends on a distill run that itself depends on nomination having already happened in a prior
invocation. A single invocation may also target just one op — e.g. the `memory-gc-overdue` finding's
apply path runs decay/demotion + review-file GC only; T1 deletion is triggered separately, by a
confirmed ADR existing to promote against.

Capture promotion is founder-gated *through distill's* gate and nomination *feeds* distill, so the
two never close a loop inside one invocation: nomination reads counters current as of the last
completed distill run, so the single-agent promotion path keeps working with a lag of at most one
distill cycle.

## Retention-window semantics

The `Review retention window` token (`.claude/project/project-context.md` Memory section, default
`6 months`) accepts exactly two forms, parsed **without heuristics** — never inferred from prose,
never guessed from a value that doesn't match either grammar exactly:

- **`<n> months`** — wall-clock. An artifact is "older than the window" when its date (a review
  file's `date` field) or its newest `evidence` entry's story's merge date (a rule entry) is more
  than `n` months before the current date.
- **`<n> stories`** — activity-based. An artifact is "older than the window" when `n` or more
  distinct story keys have been recorded in `<memory-root>/reviews/` (by filename) since its
  date (review file) or its newest `evidence` entry (rule entry). Count distinct story keys, not
  review files — a story with two review rounds on the same date contributes one story key, not
  two.

**`<n> stories` is preferred for low-activity repos** — a repo that ships infrequently would have
wall-clock decay expire still-relevant rules between commits, even though no new work has actually
superseded them. Parsing: match the token against exactly these two grammars (`^\d+ months?$` /
`^\d+ stories?$`); a value matching neither is a configuration error — surface it, do not guess a
default silently.

Captures reuse this same `Review retention window` token for the review-file GC clause (d) above —
there is no separate project-context token for the staging area.

## Concurrency behaviour

The only shared-file writes this op or any dispatched agent makes are counter-only `uses`/
`evidence` edits on `agents/shared/` rules (per the counter-only carve-out in
`refs/analyze-protocol.md`'s Memory-ownership exceptions). A conflict there — two dispatches
editing the same shared rule file in the same window — is a one-line frontmatter conflict, resolved
by taking the **higher `uses`** value and the **union of `evidence`** entries (never additive on
`uses`, never a duplicate-dropping merge that loses a story key from either side).
