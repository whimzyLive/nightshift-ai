# Memory maintenance op

Executed by `ai-enablement-engineer`. Entered from the `memory-gc-overdue` analyze finding's apply
path (`refs/analyze-protocol.md`) or by explicit founder instruction — never on a schedule, never
auto-triggered.

**Always founder-gated, always a reviewable PR, never a silent write.** This op has no auto-apply
path: every proposed change (a demotion, a deletion, a promotion) is presented to the founder and
applied only after explicit confirmation, exactly like every other apply flow in this plugin
(`refs/analyze-protocol.md#apply-flow`). A proposed deletion without founder confirmation is
refused, not queued.

## The four operations

| Op                       | Rule                                                                                                                                                                                                                                  |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Decay / demotion         | `status: active` + `uses: 0` + newest `evidence` older than the retention window → propose `status: deprecated`. Already `deprecated` and one further window elapsed → propose deletion.                                              |
| Review-file GC           | Delete a review file when (a) every id in its `## Rules written` is now `status: promoted`, or (b) it is an `issue_count: 0` marker older than the retention window, or (c) it wrote no rules and is older than the retention window. |
| ADR-candidate nomination | Nominate every rule with `uses >= 3` OR `agent` length >= 2; emit the candidate list (id, rule, evidence, uses) and hand it to `knowledge-engineer` for `/sdlc:docs distill`. **Nomination never writes an ADR.**                     |
| T1 deletion-on-promotion | When distill lands an ADR that supersedes a rule, set the rule `status: promoted`, then delete it in the maintenance PR. Promotion is one-way and terminal — a promoted rule is deleted, never revived.                               |

Run the four ops in this order when the maintenance op is invoked as a whole (decay/demotion and
review-file GC are independent of each other; nomination reads the post-decay rule set; T1 deletion
runs last since it depends on a distill run that itself depends on nomination having already
happened in a prior invocation). A single invocation may also target just one op — e.g. the
`memory-gc-overdue` finding's apply path runs decay/demotion + review-file GC only; T1 deletion is
triggered separately, by a confirmed ADR existing to promote against.

## Retention-window semantics

The `Review retention window` token (`.claude/project/project-context.md` Memory section, default
`6 months`) accepts exactly two forms, parsed **without heuristics** — never inferred from prose,
never guessed from a value that doesn't match either grammar exactly:

- **`<n> months`** — wall-clock. An artifact is "older than the window" when its date (a review
  file's `date` field) or its newest `evidence` entry's story's merge date (a rule entry) is more
  than `n` months before the current date.
- **`<n> stories`** — activity-based. An artifact is "older than the window" when `n` or more
  distinct story keys have been recorded in `.claude/memories/reviews/` (by filename) since its
  date (review file) or its newest `evidence` entry (rule entry). Count distinct story keys, not
  review files — a story with two review rounds on the same date contributes one story key, not
  two.

**`<n> stories` is preferred for low-activity repos** — a repo that ships infrequently would have
wall-clock decay expire still-relevant rules between commits, even though no new work has actually
superseded them. Parsing: match the token against exactly these two grammars (`^\d+ months?$` /
`^\d+ stories?$`); a value matching neither is a configuration error — surface it, do not guess a
default silently.

## Concurrency behaviour

The only shared-file writes this op or any dispatched agent makes are counter-only `uses`/
`evidence` edits on `agents/shared/` rules (per the counter-only carve-out in
`refs/analyze-protocol.md`'s Memory-ownership exceptions). A conflict there — two dispatches
editing the same shared rule file in the same window — is a one-line frontmatter conflict, resolved
by taking the **higher `uses`** value and the **union of `evidence`** entries (never additive on
`uses`, never a duplicate-dropping merge that loses a story key from either side).
