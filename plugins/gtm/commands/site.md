---
description: Produce reviewed, brand-correct landing-page copy with a full SEO layer — dispatches content-writer for the copy, gates it through the shared copy-review gate, applies nightshift-design brand tokens, and writes docs/gtm/site-brief.md as the durable handoff artifact. The brief is the deliverable; building the site from it is a separate step (suggested next step: the sdlc plugin).
---

Produce this repository's landing-page copy. `/gtm:site` is a **thin orchestrator** — it holds no
copy logic itself (AC-3). It dispatches `content-writer` for the copy, runs the shared copy-review
gate, applies brand tokens, then writes the handoff brief and **stops** — it never builds the site
or dispatches build agents. Building from the brief is a separate, founder-initiated step.

This command receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness — use it directly, per the
`commands/init.md` convention. Commands need no plugin-root resolver block — that mechanism is for
agents only.

## Flags

- `--council` (optional) — forwarded to the `content-writer` dispatch to enable the
  `marketing-council` critique pass. Off by default; intended for launch-critical pages only.
- `--overwrite` (optional) — non-interactive override of the re-run guard (step 1b): regenerate
  `docs/gtm/site-brief.md` without prompting.

## Step 1 — Precondition check

Verify the two context files exist and are non-empty:

```bash
[ -s ".claude/project/marketing-context.md" ] && [ -s ".agents/product-marketing.md" ] \
  && echo "PRECONDITION=ok" || echo "PRECONDITION=missing"
```

If either file is missing or empty, **STOP** before dispatching anything, with exactly:

> Run `/gtm:init` first — marketing context is not set up.

Note the guard asymmetry: `content-writer` independently enforces the
`.agents/product-marketing.md` STOP (its context contract), but the `marketing-context.md` check
exists **only here** — this precondition is the sole gate for it, not a redundant duplicate.

**Then ensure the agent's plugin-root marker exists.** The dispatched `content-writer` resolves
`${CLAUDE_PLUGIN_ROOT}` via `.claude/.gtm-plugin-root`, and that marker is a gitignored per-machine
cache — routinely absent on a fresh clone even when both context files are committed. This command
holds the native value, so write the marker before dispatching:

```bash
[ -s ".claude/.gtm-plugin-root" ] || printf '%s\n' "${CLAUDE_PLUGIN_ROOT}" > .claude/.gtm-plugin-root
```

## Step 1b — Re-run guard (decided BEFORE the expensive copy run)

Probe for an existing brief now — brief existence is knowable before the opus dispatch, and the
founder's choice must not cost a wasted copy run:

```bash
[ -f "docs/gtm/site-brief.md" ] && echo "BRIEF_EXISTS=yes" || echo "BRIEF_EXISTS=no"
```

Record a `GUARD` decision:

- **`BRIEF_EXISTS=no`** → `GUARD=fresh`. Proceed to step 2.
- **`--overwrite` passed** → `GUARD=regenerate`. Proceed to step 2, no prompt.
- **`BRIEF_EXISTS=yes` and no `--overwrite`** → prompt the founder NOW (mirrors the `/gtm:init`
  re-init guard):

  ```
  AskUserQuestion(
    header: "Existing site brief",
    question: "docs/gtm/site-brief.md already exists. How would you like to proceed?",
    multiSelect: false,
    options: [
      { label: "Refine",     description: "Generate new copy and merge it into the existing brief; the merged result is re-gated before anything is handed off." },
      { label: "Regenerate", description: "Replace the brief with a fresh copy from this run." },
      { label: "Skip",       description: "No new copy run — keep the existing brief untouched as the deliverable." }
    ]
  )
  ```

  - **Skip** → `GUARD=skip`: do **not** dispatch `content-writer` and do **not** run steps 2–5 —
    go directly to the report (step 6) with the existing brief unchanged as the deliverable. The
    report MUST note the existing brief was **not re-gated this run** — keeping it as-is is the
    founder's explicit choice.
  - **Refine** → `GUARD=refine`, **Regenerate** → `GUARD=regenerate`: proceed to step 2.

## Step 2 — Dispatch content-writer

Dispatch the `content-writer` agent with `task=landing-page`, forwarding `--council` when the flag
was passed on this command. No inline copy work happens here — the command only passes the task
through and waits for the agent's handoff artifact (copy deck + full SEO layer, per
`content-writer`'s six-section output shape). The agent returns the artifact **inline** in its
final message (or, for a very large artifact, at a session-temp scratch path — never the brief
path) — it never writes `docs/gtm/site-brief.md` itself (persistence is step 5, after the gate).

The agent's return also states whether the `marketing-council` pass ran, was skipped as
unavailable, or was not requested — carry that into the step-6 report.

## Step 3 — Copy-review gate

Run the shared gate on the returned copy artifact. The gate is a **verdict, not an edit**:

- Load the marketingskills `copy-editing` skill **as review criteria only** — use its editing
  principles to judge the copy. Do **not** apply its edits, rewrite, or "improve" the artifact; the
  gate never produces revised copy (the no-automatic-revision rule is a product-owner decision).
- Evaluate the artifact against the merged rule set: `${CLAUDE_PLUGIN_ROOT}/refs/voice-rules.md`
  (hard bans + positioning discipline) layered with the project's `marketing-context.md` Voice
  overrides — project overrides win on direct conflict; un-overridden plugin bans stay in force.
- Emit exactly **PASS** or **FAIL** per `voice-rules.md`'s gate outcome contract. This is the same
  gate `/gtm:pulse` will reuse once NA-8 lands.

Outcomes:

- **PASS** — proceed to step 4.
- **FAIL** — emit the violation list (each violation with its offending span, per
  `voice-rules.md`'s gate outcome contract) **plus the final report in the step-6 format** (step 6
  states which fields apply on a FAIL run), then **end the run — steps 4–5 are skipped**. Nothing
  is branded and nothing is written to `docs/gtm/site-brief.md`. There is no automatic revision
  loop — the founder addresses the violations and re-runs `/gtm:site`.

## Step 4 — Apply brand tokens

Apply `nightshift-design` brand tokens, sourced from `brand/BRAND_KIT.md`, to the copy/section
artifact so the handoff carries brand-correct typography, colour, and voice tokens. This is styling
metadata attached to the copy deck — not a visual build.

If `brand/BRAND_KIT.md` is missing, degrade gracefully: proceed with an unbranded copy deck and note
the missing brand kit in the final report (step 6). Do not hard-fail — brand is additive to copy,
not a precondition for it.

## Step 5 — Write the brief

### 5a. Persist per the step-1b `GUARD` decision

- **`GUARD=fresh` / `regenerate`** — write this run's gated, branded artifact to
  `docs/gtm/site-brief.md`.
- **`GUARD=refine`** — merge the newly generated changes into the existing brief, then **re-run
  the step-3 gate on the MERGED brief** (retained old spans were never gated this run; only the
  merged whole passing the gate satisfies AC-4 for the actual handoff artifact).
  - Merged gate **PASS** → write the merged brief to `docs/gtm/site-brief.md`.
  - Merged gate **FAIL** → leave the existing brief untouched, and preserve this run's work: write
    the fresh gated artifact to `docs/gtm/site-brief.new.md` (same provenance header) so the copy
    run is not lost. Report the FAIL (step-6 format, refine-FAIL variant) and **end the run**.
- **`GUARD=skip`** — step 5 does not run (the run jumped from 1b to the step-6 report).

Every brief written this step carries a one-line provenance header at the top of the file: the
write date and the source command, e.g. `<!-- generated 2026-07-09 by /gtm:site -->`.

### 5b. The brief is the deliverable

`docs/gtm/site-brief.md` is the durable handoff artifact and the **terminal output** of this
command — freshly written on `fresh`/`regenerate`/`refine`-PASS, or the retained existing brief on
a step-1b **skip** (founder's explicit choice; no new copy run occurred). The brief carries the
full SEO layer (AC-5): page map/IA, copy deck, JSON-LD, meta/OG, and llms.txt recommendation,
matching `content-writer`'s six handoff sections (brand tokens populated per step 4 on written
briefs).

**This command never dispatches build agents** — even when the sdlc plugin is installed. A repo
with the brief ready may still lack the frameworks, skills, and project setup a build needs, so
building is always a separate, founder-initiated step (see the next-steps guidance in step 6).

## Step 6 — Report

Return (fields marked *(completed runs)* apply only when the run produced or retained a brief. On a
**step-3** gate-FAIL state explicitly that **no brief was written and no guard action ran**, with
the violation list. On a **refine-merge** gate-FAIL (step 5a): the guard action was refine, the
existing brief is untouched, and the fresh artifact was preserved at `docs/gtm/site-brief.new.md`
— report that path with the violation list):

1. *(completed runs)* The brief path (`docs/gtm/site-brief.md`) and the `GUARD` action applied
   (fresh / refine / regenerate / skip / `--overwrite`); on a refine-FAIL, the preserved
   `docs/gtm/site-brief.new.md` path.
2. *(completed runs)* **Next steps**: the brief is the standalone deliverable — suggest the
   founder installs the sdlc plugin (if not already installed) and uses its flow to build the site
   from the brief separately, once the repo is set up with the frameworks and skills the build
   needs. Never dispatch that build from this command. On a `GUARD=skip` run: also state that the
   existing brief was kept **without re-gating**, per the founder's choice.
3. The copy-review gate result — PASS, FAIL (with the violation list; on a step-3 FAIL steps 4–5
   never ran, on a refine-merge FAIL the existing brief was not replaced), or **not run**
   (`GUARD=skip`).
4. The `marketing-council` status from the agent's return (ran / skipped-unavailable / not
   requested).
5. Any open copy decisions flagged by `content-writer` or the gate that need a founder call.

## Error handling

| Scenario | Behaviour |
|----------|-----------|
| `.agents/product-marketing.md` missing/empty | Command STOPs at step 1 with the "run `/gtm:init`" guidance; `content-writer` also enforces this specific STOP independently. |
| `marketing-context.md` missing/empty | Command STOPs at step 1 (precondition — this is the ONLY guard for this file; the agent does not re-check it). |
| `.claude/.gtm-plugin-root` missing | Not an error — step 1 writes it from the command's native `${CLAUDE_PLUGIN_ROOT}` before dispatch (it is a gitignored per-machine cache). |
| Copy-review gate FAIL | Command STOPs after step 3; reports each violation + offending span in the step-6 FAIL format; nothing branded or written. |
| Refine-merge gate FAIL | Existing brief left untouched; fresh artifact preserved at `docs/gtm/site-brief.new.md`; run ends with the FAIL report. |
| `task=channel-draft` requested | `content-writer` STOPs: "task=channel-draft is not available until NA-8." |
| `docs/gtm/site-brief.md` already exists | Re-run guard (step 1b, before the copy run): prompt refine / regenerate / skip; `--overwrite` bypasses the prompt. Never silently overwritten. |
| `brand/BRAND_KIT.md` missing | Degrade: proceed with an unbranded copy deck, note the missing brand kit in the report (step 6). Do not hard-fail — brand is additive. |
| `--council` passed but `marketing-council` skill unavailable | `content-writer` skips the pass and flags the skip in its return (its documented fallback); the command surfaces it in the step-6 report. Non-fatal; the gate still runs. |
