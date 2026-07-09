---
description: Produce reviewed, brand-correct landing-page copy with a full SEO layer and route it to a build — dispatches content-writer for the copy, gates it through the shared copy-review gate, applies nightshift-design brand tokens, always writes docs/gtm/site-brief.md as the durable handoff artifact, and additionally dispatches sdlc's web-engineer when sdlc is installed.
---

Produce this repository's landing-page copy and route it to a build. `/gtm:site` is a **thin
orchestrator** — it holds no copy logic itself (AC-3). It dispatches `content-writer` for the copy,
runs the shared copy-review gate, applies brand tokens, then writes the handoff brief and routes
the build.

This command receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness — use it directly, per the
`commands/init.md` convention. Commands need no plugin-root resolver block — that mechanism is for
agents only.

## Flags

- `--council` (optional) — forwarded to the `content-writer` dispatch to enable the
  `marketing-council` critique pass. Off by default; intended for launch-critical pages only.
- `--overwrite` (optional) — non-interactive override of the re-run guard (step 5a): regenerate
  `docs/gtm/site-brief.md` without prompting.

## Step 1 — Precondition check

Verify both exist:

```bash
[ -f ".claude/project/marketing-context.md" ] && [ -s ".agents/product-marketing.md" ] \
  && echo "PRECONDITION=ok" || echo "PRECONDITION=missing"
```

If either is missing or empty, **STOP** before dispatching anything, with exactly:

> Run `/gtm:init` first — marketing context is not set up.

This is a fail-fast duplicate of `content-writer`'s own context-contract STOP — checking here gives
a cleaner message and avoids a wasted dispatch, but the agent enforces the same guard independently.

## Step 2 — Dispatch content-writer

Dispatch the `content-writer` agent with `task=landing-page`, forwarding `--council` when the flag
was passed on this command. No inline copy work happens here — the command only passes the task
through and waits for the agent's handoff artifact (copy deck + full SEO layer, per
`content-writer`'s six-section output shape).

## Step 3 — Copy-review gate

Run the shared gate on the returned copy artifact: the marketingskills `copy-editing` skill
**plus** `${CLAUDE_PLUGIN_ROOT}/refs/voice-rules.md` — the merged project + plugin rules (project
`marketing-context.md` Voice overrides win on direct conflict; un-overridden plugin bans in
`voice-rules.md` stay in force). This is the same gate `/gtm:pulse` will reuse once NA-8 lands.

- **PASS** — proceed to step 4.
- **FAIL** — report each violation with its offending span (per `voice-rules.md`'s gate outcome
  contract) and **STOP**. Nothing is branded, nothing is written to `docs/gtm/site-brief.md`, and no
  web-engineer dispatch happens. There is no automatic revision loop — the founder addresses the
  violations and re-runs `/gtm:site`.

## Step 4 — Apply brand tokens

Apply `nightshift-design` brand tokens, sourced from `brand/BRAND_KIT.md`, to the copy/section
artifact so the handoff carries brand-correct typography, colour, and voice tokens. This is styling
metadata attached to the copy deck — not a visual build.

If `brand/BRAND_KIT.md` is missing, degrade gracefully: proceed with an unbranded copy deck and note
the missing brand kit in the final report (step 6). Do not hard-fail — brand is additive to copy,
not a precondition for it.

## Step 5 — Write the brief, then route the build

### 5a. Re-run guard (before writing)

If `docs/gtm/site-brief.md` already exists, do not silently overwrite it (mirrors the `/gtm:init`
re-init guard):

```bash
[ -f "docs/gtm/site-brief.md" ] && echo "BRIEF_EXISTS=yes" || echo "BRIEF_EXISTS=no"
```

- **`--overwrite` passed** — regenerate without prompting.
- **`BRIEF_EXISTS=no`** — write fresh, no prompt needed.
- **`BRIEF_EXISTS=yes` and no `--overwrite`** — prompt the founder:

  ```
  AskUserQuestion(
    header: "Existing site brief",
    question: "docs/gtm/site-brief.md already exists. How would you like to proceed?",
    multiSelect: false,
    options: [
      { label: "Refine",     description: "Update the existing brief with the newly generated changes." },
      { label: "Regenerate", description: "Replace it with a fresh copy from this run." },
      { label: "Skip",       description: "Keep the existing brief untouched; continue to routing with it." }
    ]
  )
  ```

Every brief written this step (fresh, refine, regenerate, or `--overwrite`) carries a one-line
provenance header at the top of the file: the write date and the source command, e.g.
`<!-- generated 2026-07-09 by /gtm:site -->`.

### 5b. Always write `docs/gtm/site-brief.md`

Regardless of sdlc presence, `docs/gtm/site-brief.md` is the durable handoff artifact and is
**always** written in both branches below — except on a 5a **skip**, where the existing brief is
retained untouched and nothing new is written this run. The brief carries the full SEO layer (AC-5):
page map/IA, copy deck, JSON-LD, meta/OG, and llms.txt recommendation, matching `content-writer`'s
six handoff sections (brand tokens now populated per step 4).

### 5c. sdlc present

Detect sdlc by checking for its plugin-root marker:

```bash
[ -f ".claude/.sdlc-plugin-root" ] && echo "SDLC=present" || echo "SDLC=absent"
```

If `SDLC=present`, additionally dispatch sdlc's web-engineer **by agent name**
(`sdlc:web-engineer`, via the Agent tool) with `docs/gtm/site-brief.md` as its build input — never
by a hardcoded file path into `plugins/sdlc/...` (in a consumer repo, sdlc lives under the
`.claude/.sdlc-plugin-root` marker's root, not necessarily at that path).

### 5d. sdlc absent

If `SDLC=absent`, no dispatch happens — the brief alone is the deliverable. The founder wires the
build up manually or installs sdlc later.

## Step 6 — Report

Return:

1. The brief path (`docs/gtm/site-brief.md`) and the guard action taken (fresh write / refine /
   regenerate / skip / `--overwrite`).
2. Whether `sdlc:web-engineer` was dispatched (and, if not, that the brief is the standalone
   deliverable).
3. The copy-review gate result (PASS, or that the run stopped on FAIL — in which case steps 4–5
   never ran).
4. Any open copy decisions flagged by `content-writer` or the gate that need a founder call.

## Error handling

| Scenario | Behaviour |
|----------|-----------|
| `.agents/product-marketing.md` missing/empty | Command STOPs at step 1 with the "run `/gtm:init`" guidance; `content-writer` also enforces the same STOP independently. |
| `marketing-context.md` missing | Command STOPs at step 1 (precondition). |
| Copy-review gate FAIL | Command STOPs after step 3; reports each violation + offending span; nothing branded or handed off. |
| `task=channel-draft` requested | `content-writer` STOPs: "task=channel-draft is not available until NA-8." |
| sdlc absent at handoff | Non-error — the always-written brief is the deliverable; the report notes no web-engineer dispatch occurred. |
| `docs/gtm/site-brief.md` already exists | Re-run guard (step 5a): prompt refine / regenerate / skip; `--overwrite` bypasses the prompt. Never silently overwritten. |
| `brand/BRAND_KIT.md` missing | Degrade: proceed with an unbranded copy deck, note the missing brand kit in the report (step 6). Do not hard-fail — brand is additive. |
| `--council` passed but `marketing-council` skill unavailable | Warn the critique pass is skipped; continue (the gate still runs). Non-fatal. |
