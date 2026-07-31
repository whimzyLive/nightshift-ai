---
description: Full SDLC automation for a Jira story. Quality-assesses and triages if needed, then delegates the complexity decision to the shared triage protocol (refs/triage.md, applied inline) and routes a `full` story through the two-phase spec → review-gate → plan+impl-single-PR flow, or a `lightweight` story (<= threshold pts, inclusive) straight to implementation. Posts Jira comments at each gate with clickable PR links. Pass --async-review for non-blocking service-driven execution where JSON-RPC events replace the human confirmation gate.
---

Parse $ARGUMENTS:

- `STORY_KEY` = $ARGUMENTS with `--async-review` stripped (e.g. `CER-123 --async-review` → `CER-123`)
- `ASYNC_REVIEW` = `true` if `--async-review` present in $ARGUMENTS, else `false`

## Step 0 — Detect the input type (Story vs Epic)

`/auto` accepts **either** a single Story key (its original behaviour) **or** an Epic key (drives
every child story to completion). Decide which by probing the issue type **definitively** — never
scrape `acli workitem view` rendered text (that format is not stable across acli versions/flags).
Read the structured `issuetype.name` field and compare case-insensitively:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
ITYPE="$(acli jira workitem view STORY_KEY --fields issuetype --json 2>/dev/null \
           | jq -r '.fields.issuetype.name // empty' | tr '[:upper:]' '[:lower:]')"
```

Route on `ITYPE`:

- `story` **or** `bug` (or any non-epic _implementable_ type your project routes through `/auto` as a
  single story) → **continue to Step 1 below — the single-story flow is UNCHANGED.** A `bug` is an
  implementable single-story type: it flows the same single-story path as `story`, and the inline
  triage step (Step 2) classifies it `WORK_KIND=defect` + forces `TRIAGE=lightweight` → Workflow B
  (the systematic-debugging defect path). **Retain `ITYPE` for Steps 1–2** — it is threaded into the
  inline triage step (so triage derives `WORK_KIND` with zero extra Jira I/O) and gates the Step-2
  missing-points bypass.
- `epic` → **read `${CLAUDE_PLUGIN_ROOT}/refs/epic-orchestration.md` (explicit path) now and follow
  it — do NOT run Steps 1+ for the epic key itself.** Each child story runs its own full `/auto`
  single-story flow in a child session. If the ref is unreadable → **STOP** with the missing path;
  never continue on a half-loaded contract. **The single-story path below never reads this ref.**
- `sub-task` / any other type / an empty/unreadable probe → **STOP** with `unsupported input type`.
  Tell the user: "STORY_KEY is not a Story, Bug, or Epic (issuetype=`<name>`) — `/auto` drives a single
  story/bug or a whole epic; unsupported input type." Spawn **no** session. Then run the direct
  `session-complete.sh` release (see **Final action**) and exit.

> Everything from **Step 1** onward is the **single-story** flow. It is entered only for a Story-type
> key (whether you ran `/auto <STORY>` directly or the epic loop spawned a child `/auto <STORY>`),
> and behaves exactly as it always has. The epic path never falls through into Step 1 for the epic
> key — it loops over children, each of which is itself a single-story `/auto` run.

## Step 1 — Assess

Dispatch the `scrum-master` agent in **Mode 3 (Auto-Assess)** with `STORY_KEY`.

Wait for its response — it returns exactly:

```
QUALITY=ok|triaged
STORY_POINTS=N|missing
```

## Step 2 — Route

**First, short-circuit on missing points from Step 1 — but BYPASS this for Bugs.** If `ITYPE == bug`
(from Step 0), **skip the missing-points short-circuit entirely** and proceed to the inline triage
step: a Bug needs no points to route (triage forces `WORK_KIND=defect` + `TRIAGE=lightweight`
regardless of points). Otherwise — `ITYPE != bug` **and** scrum-master returned `STORY_POINTS=missing`
— **stop here**: do NOT run the triage step (it would only re-fetch Jira and return `full` + a
warning, and a transient triage `acli` failure could then leave `/auto` unable to route despite Step 1
having already succeeded). Tell the user: "Story points not set on STORY_KEY — story has been triaged.
Set story points in Jira, then re-run `/auto STORY_KEY`."

> **Why this bypass keys off `ITYPE`, not `WORK_KIND` (load-bearing ordering).** `WORK_KIND` is
> produced by `refs/triage.md`, which runs **after** this short-circuit — so `WORK_KIND` does **not
> yet exist** here. Keying the bypass off `WORK_KIND` would be unimplementable; it keys off the issue
> type already detected at Step 0 (`ITYPE == bug`). **Transient-failure note:** skipping the
> short-circuit for Bugs means a Bug now always reaches the inline triage call, so a transient `acli`
> failure there surfaces as the standard acli-failure STOP (no `WORK_KIND`/`TRIAGE` block) — a clean,
> **re-runnable** STOP, not a silent misroute (a re-run routes the Bug correctly because `ITYPE == bug`
> is known from Step 0). The short-circuit's real guarantee (never _silently_ mis-route) is preserved;
> only the "avoid the triage call entirely" optimisation is traded away for Bugs, by design.

Otherwise, run the triage step by **applying `${CLAUDE_PLUGIN_ROOT}/refs/triage.md` INLINE** (in
this same session), **threading the Step-0 `ITYPE` in as the optional `<ISSUE_TYPE>` input** (so
triage derives `WORK_KIND` from it with zero extra Jira I/O — do not let triage re-fetch the issue
type on the `/auto` path), and route on its `TRIAGE` outcome — the single shared definition of the
lightweight/full decision (default threshold `<= 3` points ⇒ lightweight, inclusive; configurable
per-repo). The inline triage step now also emits `WORK_KIND=defect|feature` — capture it and thread
it into the Workflow's impl phase (it drives the playbook's defect variant + branch prefix). If the
triage step STOPs **without** emitting the required `WORK_KIND=`/`TRIAGE=`/`STORY_POINTS=`
block (e.g. an `acli` auth/DNS failure), **STOP** and surface that error — do not guess a route.

> **Do NOT invoke the `/triage` slash command here.** `/triage` is a top-level command whose final
> action runs `session-complete.sh`, which (under the automation harness) emits the session-complete
> sentinel and releases this worker slot — mid-`/auto`, before plan/impl have run. `/auto` owns the
> single release at the very end. Apply the **ref** inline; never call the **command** from inside
> `/auto`. (`refs/triage.md` is pure routing logic and emits no sentinel.)

- `TRIAGE=full` → **Workflow A** (Phase 1: spec + review gate → Phase 2: plan + impl in a single PR)
- `TRIAGE=lightweight` → **Workflow B** (direct impl — **no spec, no plan doc, no review gate**; tasks derived inline from the story)

(Step 1's scrum-master `STORY_POINTS=N|missing` gates the `missing` stop **before** the triage step
runs; the complexity routing itself is delegated to the shared `refs/triage.md` protocol — applied
inline, not the `/triage` command — so `/auto` and `/impl` share one definition.)

---

## Loop-after-raise + mode-conditioned terminal action (shared by A1, A2, B1)

Every phase that raises a PR drives the Copilot review-fix loop on it **before** the phase finishes,
then takes a terminal action that depends on the story's mode. A1, A2, and B1 below each invoke this
procedure with their just-raised `<PR_URL>` and a `<PHASE>` of `spec` (advances to Phase 2 on
merge), `plan+impl`, or `impl` (completes the story on merge).

The loop is also handed a **`--phase <GATE_PHASE>`** flag so the per-repo **Review gate** can skip
this phase's review (see **Review Gate** below). The gate-phase maps from the workflow branch:
**A1 spec PR → `spec`**, **A2 combined plan+impl PR → `impl`**, **B impl PR → `impl`**. (The combined
plan+impl PR uses `impl`: there is no separate plan PR in `/auto`.) `<GATE_PHASE>` is passed
literally per-invocation, so there is no cross-phase state bleed.

### Resolving the working issue's mode

The terminal action (auto-merge vs leave for a human) depends on the story's AI workflow mode. Do
**not** parse `acli workitem view` text output — that format is not stable across acli
versions/flags, and a parse miss would silently disable Full Auto. Instead probe **definitively**
with a JQL match (the repo's established custom-field-read pattern — see `refs/jira-fetch.md`), so
auto-merge is enabled **only** when Jira itself confirms the mode is `Full Auto`.

The mode has two sources, in strict precedence order:

1. **The `"AI Workflow"` custom field** — always wins when it is set to anything.
2. **An `AI-Workflow:<mode>` label fallback** — consulted **only when the field is unset or the
   field doesn't exist on the instance**. Projects that cannot add custom fields opt in via a label
   instead: `AI-Workflow:full-auto`, `AI-Workflow:auto`, or `AI-Workflow:assisted` (lowercase mode
   tokens). When a story carries **multiple** `AI-Workflow:*` labels, the **most conservative** one
   wins (`assisted` > `auto` > `full-auto`) — the label probes below check most-conservative first,
   so the ladder's order encodes that rule.

`MODE` always resolves to a **real mode string** (`Full Auto` / `Auto` / `Assisted`), or empty when
**neither source is set** — never a placeholder — because callers interpolate it into
operator-facing text (e.g. the epic loop's E2b gate prompt via `storyMode(S)`).

Resolve it via the shared ladder script (collapses this ladder and E0's `epicFallback` ladder into
one implementation — NA-86 A6):

```bash
eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-ai-workflow-mode.sh STORY_KEY)"
# -> sets MODE ('Full Auto' | 'Auto' | 'Assisted' | '') and MODE_SOURCE (additive
#    observability only — D9, no caller branches on it)
```

`MODE="Full Auto"` is the **only** value that enables auto-merge. Any other outcome (`Auto`,
`Assisted`, empty, or a JQL/auth error that yields no match) → the **human-merge** path. Defaulting
to the human path is the safe failure mode: a transient read error must never trigger an unattended
merge. (The `"AI Workflow"` field name is the consuming repo's single-select; the JQL match is
case- and format-stable, unlike scraping view output. On an instance where the field doesn't exist
at all, the field probes error → no match → the label probes still run, which is exactly the
fallback's target case. The label tokens deliberately mirror the mode values the consuming repo's
trigger service resolves from the same labels, so webhook-side triggering and `/auto`-side gating
agree.)

### The procedure (release at PR raise; the loop is a NEW session)

1. **Resolve `MODE`** (see above) — this decides whether an `--on-clean` hook is attached.
2. **Resolve `DONE_STATUS`** — read the **`Pipeline done status`** row from this repo's
   `.claude/project/project-context.md` (the same token E2a's idempotent-skip check reads; no new
   terminal status is introduced here). Only needed when `MODE` = `Full Auto` **and** `<PHASE>` is
   story-COMPLETING (see step 3) — resolve it unconditionally here for simplicity, it is simply
   unused otherwise.
3. **Post the phase's Jira comment FIRST** (the loop is the session's last act, so the comment is
   posted before it — see A1/A3/B2 for the per-phase, mode-aware text).
4. **Build `<NEXT>`, the full re-invocation line:**
   - **`MODE` = `Full Auto`** → attach the auto-merge hook; on `<NEXT>`'s clean exit it auto-merges
     `<PR_URL>`, whose merge event advances the pipeline (`<PHASE>=spec` → resumes Phase 2;
     `plan+impl`/`impl` → completes the story and also best-effort transitions it to
     `<DONE_STATUS>`). Whether the hook also transitions the story depends on **whether `<PHASE>` is
     story-COMPLETING**:
     - **`<PHASE>` = `plan+impl` or `impl`** (story-COMPLETING — A2/A3's combined PR, or B1/B2's impl
       PR) → pass `<STORY_KEY>` and `<DONE_STATUS>` so the hook transitions the story after the
       verified merge:
       ```bash
       /loop /sdlc:loop <PR_URL> --phase <GATE_PHASE> --on-clean "bash ${CLAUDE_PLUGIN_ROOT}/scripts/auto-merge-pr.sh <PR_URL> <STORY_KEY> \"<DONE_STATUS>\""
       ```
     - **`<PHASE>` = `spec`** (A1's spec PR — does NOT complete the story; the pipeline just advances
       to Phase 2) → the 1-arg, merge-only invocation, no transition:
       ```bash
       /loop /sdlc:loop <PR_URL> --phase <GATE_PHASE> --on-clean "bash ${CLAUDE_PLUGIN_ROOT}/scripts/auto-merge-pr.sh <PR_URL>"
       ```
   - **Any other mode** → no hook; `<NEXT>` just drives the PR to Copilot-clean and stops for a human
     merge:
     ```bash
     /loop /sdlc:loop <PR_URL> --phase <GATE_PHASE>
     ```
   Then apply **Session boundary at PR raise** (below) to `<NEXT>`.

> **Fallback** — if the harness cannot self-invoke the native `/loop` from inside `/auto`: drive
> `sdlc:loop`'s pass-cycle via `ScheduleWakeup` yourself and run the resolved `--on-clean` command at
> the rule-4 clean exit, then apply **Session boundary at PR raise** to the assembled `<NEXT>` exactly
> as the harness path would.

`sdlc:loop` stays mode-agnostic — it only drives review-fix and runs whatever `--on-clean` hook it
was handed; `/auto` decides (via `MODE`) whether to attach the auto-merge hook.

### Review Gate

The optional **`Review gate`** token in the repo's `## Code Review` section is a comma-separated
subset of `spec,plan,impl` listing which phases trigger the configured automated review:

- A phase listed in the gate reviews as usual; a phase **not** listed has its review skipped (the
  reader returns effective `REVIEW_MODE=none`, so `raise-pr.sh` requests no reviewer and the tail
  loop runs `--on-clean` once and releases — the pipeline advances without waiting for a review).
- **Token absent or empty ⇒ all phases review** — the default, fully back-compatible behaviour
  (no regression).
- The combined plan+impl PR is gated by the **`impl`** value (there is no separate plan PR in
  `/auto`); the spec PR is gated by `spec`.
- The phase is passed per-invocation as `--phase <GATE_PHASE>`, so each PR is gated independently and
  there is no cross-phase state bleed.

### Session boundary at PR raise

The top-level session re-bills every resident tool result on every later turn; 34.6% of top-level
tool-result exposure is the post-PR-raise tail inheriting context produced before the PR existed
(NA-91). The phase **closes** at PR raise — the work is durable on a branch and the Jira comment is
posted — so the tail runs as a NEW session instead of inheriting this one. `<NEXT>` is the FULL
re-invocation line, including `--phase <GATE_PHASE>` and the `--on-clean` hook when one applies.

```text
SDLC_BOUNDARY_ON unset                        -> run <NEXT> inline as today's tail; the loop owns
                                                  the release   # DEFAULT: unchanged behaviour
SDLC_BOUNDARY_ON set + SDLC_SESSION_KEY set   -> print `<<<SDLC_NEXT_INVOCATION:<NEXT>>>>`, run
                                                  `session-complete.sh <PR_URL>`, STOP   # harness
                                                  re-invokes <NEXT> fresh
SDLC_BOUNDARY_ON set + SDLC_SESSION_KEY unset -> interactive: print <NEXT>, then run it inline as
                                                  the tail; the loop releases
```

first-match-wins, and the boundary is **opt-in**: the default row (`SDLC_BOUNDARY_ON` unset) is
byte-identical to today's behaviour, because the harness protocol it depends on does not ship itself.
The harness re-invokes the printed line **verbatim**: `session-complete.sh` is unchanged and its
`|PR=` marker cannot carry `--phase` or an `--on-clean` hook, so the line is printed, never
reconstructed. **A harness must adopt `SDLC_NEXT_INVOCATION` before `SDLC_BOUNDARY_ON` is ever set**
— setting it against a harness that ignores the line leaves every PR raised under the boundary
unlooped, unreviewed, and never auto-merged, silently.

---

## Workflow A — `TRIAGE=full`

Two phases, gated by the **spec PR merge**:

- **Phase 1 (Spec):** generate the spec **only**, raise the spec PR, then **stop** for human review + merge. No plan, no impl in this run.
- **Phase 2 (Plan + Impl):** once the spec PR is merged to `develop` and `/auto STORY_KEY` is re-run (or, in async mode, the service re-invokes), generate the plan **and** run implementation on **one branch** and raise a **single PR** containing both the plan doc and the code.

### A0 — Determine phase

In **both** sync and async modes, the phase is decided by whether the spec is already merged to `develop`:

```bash
git fetch origin develop --quiet
SPEC_EXISTS=$(git show origin/develop:docs/superpowers/specs/STORY_KEY.md > /dev/null 2>&1 && echo yes || echo no)
```

- `SPEC_EXISTS=no` → run **Phase 1 (A1)** — spec only, then stop.
- `SPEC_EXISTS=yes` → run **Phase 2 (A2)** — plan + impl in a single PR.

This makes the spec PR merge the single resume point: re-running `/auto STORY_KEY` after merging the spec PR automatically continues into Phase 2.

---

### A1 — Spec (Phase 1)

Dispatch the `solutions-architect` agent as instructed in `${CLAUDE_PLUGIN_ROOT}/commands/spec.md` for `STORY_KEY`.
Wait for completion. Capture the returned spec PR URL as `SPEC_PR_URL`.

**If ASYNC_REVIEW=true** — fire JSON-RPC event then stop:

```bash
curl -s --retry 3 -X POST http://localhost:9001 \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"phase/pr_raised\",\"params\":{\"storyKey\":\"STORY_KEY\",\"type\":\"spec\",\"url\":\"SPEC_PR_URL\"},\"id\":1}"
```

**Exit.** Do not continue to A2. The service re-invokes (Phase 2) when the spec PR is merged.

**If ASYNC_REVIEW=false** — resolve `MODE`, post the mode-aware Jira comment, then run the
**Loop-after-raise** procedure (above) for the spec PR as the session **tail** (`<PR_URL>`=`SPEC_PR_URL`,
`<PHASE>`=`spec`). The comment is posted **before** the loop (the loop is the last act). Run the site
guard once before either branch below:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
```

- **`MODE`=`Full Auto`** → post an intent note, then run the tail loop **with** the auto-merge hook
  (it auto-merges the spec PR on clean exit; that merge webhook then resumes Phase 2 automatically):

```bash
acli jira workitem comment create --key STORY_KEY --body "Spec PR raised (Full Auto): SPEC_PR_URL

Driving Copilot review-fix now; will auto-merge once review + checks pass, then advance to plan + implementation automatically."
```

- **Any other mode** → post the human-merge note, then run the tail loop **without** a hook (drives
  the PR to Copilot-clean, leaves it open for a human merge):

```bash
acli jira workitem comment create --key STORY_KEY --body "Spec PR ready for review.

Spec PR: SPEC_PR_URL

Driven to Copilot-clean. Review and merge to develop, then re-run /auto STORY_KEY to generate the plan and implementation in a single PR."
```

Tell the user:

> Spec PR raised; driving it to Copilot-clean as the session tail. Review and merge it to `develop`, then re-run `/auto STORY_KEY`.

Terminal action: apply **Session boundary at PR raise**. Do **not** proceed to A2
in this run; Phase 2 is resumed by the spec-PR merge (human, or the Full-Auto auto-merge) as a fresh
`/auto STORY_KEY` invocation (A0 detects the merged spec).

---

### A2 — Plan + Implement (Phase 2, single PR)

**Precondition:** spec is merged to `develop` (verified by A0). Plan and implementation share **one branch** and ship as **one PR** — there is no separate plan PR.

1. **Branch.** Create the implementation branch `feat/STORY_KEY` off `develop`.
2. **Plan.** Dispatch the `tech-lead` agent for `STORY_KEY` to produce `docs/superpowers/plans/STORY_KEY.md` as instructed in `${CLAUDE_PLUGIN_ROOT}/commands/plan.md`, but **commit the plan doc onto `feat/STORY_KEY`** — do **not** create a separate plan branch or plan PR. (Same plan content as `/plan`; only the delivery target changes.)
3. **Implement.** Run the implementation exactly as `${CLAUDE_PLUGIN_ROOT}/commands/impl.md` specifies for `STORY_KEY`: execute the Principal Engineer playbook (`${CLAUDE_PLUGIN_ROOT}/refs/principal-engineer-playbook.md`) **inline in this session** — dispatch the domain agents yourself with the `Agent` tool, working on the **existing `feat/STORY_KEY` branch** (do not create a new branch). Do NOT dispatch a `principal-engineer` subagent (nesting is blocked; it cannot dispatch domain agents). (The playbook's Step 6.5 runs a post-QA docs sync on the `clean` verdict, before the PR, so regenerated docs land in the same `feat/STORY_KEY` PR — a docs-content failure WARNs, not blocks.)
4. **Single PR.** Raise one PR from `feat/STORY_KEY` → `develop` containing **both** the plan doc and the implementation. Capture its URL as `IMPL_PR_URL`.

**If ASYNC_REVIEW=true** — fire **both** `pr_raised` events for the single PR (`type=plan` then `type=impl`), both pointing at `IMPL_PR_URL`. The plan and impl now ship in one PR, so the service's spec→plan→impl state machine is satisfied by emitting both phases against that PR; merging it confirms both:

```bash
curl -s --retry 3 -X POST http://localhost:9001 \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"phase/pr_raised\",\"params\":{\"storyKey\":\"STORY_KEY\",\"type\":\"plan\",\"url\":\"IMPL_PR_URL\"},\"id\":1}"
curl -s --retry 3 -X POST http://localhost:9001 \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"phase/pr_raised\",\"params\":{\"storyKey\":\"STORY_KEY\",\"type\":\"impl\",\"url\":\"IMPL_PR_URL\"},\"id\":2}"
```

5. **Comment, then loop (tail).** Resolve `MODE`, post the mode-aware A3 comment **before** the loop,
   then run the **Loop-after-raise** procedure (above) for the impl PR as the session **tail**
   (`<PR_URL>`=`IMPL_PR_URL`, `<PHASE>`=`plan+impl`): `Full Auto` → tail loop **with** the auto-merge
   hook (auto-merges on clean → the plan+impl PR landing on `develop` **completes** the story, then
   best-effort transitions it to the pipeline done status); any other mode → tail loop **without** a
   hook (leave open for human merge). Terminal action: apply **Session boundary at PR raise**.

### A3 — Complete (comment posted BEFORE the tail loop)

Post the mode-aware comment now — before the loop, since the loop is the session's last act (intent
tense; any merge happens inside the loop's clean exit). Run the site guard once before either branch
below:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
```

- **`Full Auto`:**

```bash
acli jira workitem comment create --key STORY_KEY --body "Plan and implementation complete (Full Auto).

PR: IMPL_PR_URL

Single PR contains the implementation plan and code. Driving Copilot review-fix; will auto-merge once review + checks pass, then transition this story to the pipeline done status. Spec was merged separately."
```

- **Any other mode:**

```bash
acli jira workitem comment create --key STORY_KEY --body "Plan and implementation complete.

PR: IMPL_PR_URL

Single PR contains the implementation plan and code, driven to Copilot-clean. Review and merge to develop. Spec was reviewed and merged separately."
```

**If ASYNC_REVIEW=true** — fire completion event:

```bash
curl -s --retry 3 -X POST http://localhost:9001 \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"phase/complete\",\"params\":{\"storyKey\":\"STORY_KEY\",\"implUrl\":\"IMPL_PR_URL\"},\"id\":1}"
```

---

## Workflow B — `TRIAGE=lightweight`

Lightweight stories go **straight from triage to implementation** — **no spec, no plan doc, and no
review gate**. There is **no plan-generation step**: the implementation derives its tasks inline from
the Jira story description (exactly as standalone `/impl` does on its lightweight path). This is the
deliberate fast-path for small (≤ threshold-points) stories — the spec/plan ceremony is reserved for
`full` stories (Workflow A).

> **No `docs/superpowers/plans/STORY_KEY.md` is created or required on this path.** A plan doc is
> neither generated (no `tech-lead` dispatch) nor a precondition. If you _want_ a recorded plan and a
> review gate, the story should be triaged `full` (raise its story points above the threshold).

### B1 — Implement (direct)

Run the implementation exactly as `${CLAUDE_PLUGIN_ROOT}/commands/impl.md` specifies for `STORY_KEY`: execute
the Principal Engineer playbook (`${CLAUDE_PLUGIN_ROOT}/refs/principal-engineer-playbook.md`) **inline in this
session** with **`LIGHTWEIGHT=true`** **and the `WORK_KIND` captured from Step 2's inline triage**
(`defect` for a Bug, `feature` otherwise) — dispatch the domain agents yourself with the `Agent` tool. On
its lightweight path the playbook skips the plan-file STOP and **derives tasks inline from the Jira story**
(Step 2), so no plan doc is needed. **`WORK_KIND=defect` activates the playbook's systematic-debugging
defect variant** (reproduce → root-cause → failing regression test → fix+verify) on a `fix/STORY_KEY`
branch; `WORK_KIND=feature` keeps the normal feature ladder on `feat/STORY_KEY`. Do NOT dispatch a
`principal-engineer` subagent (nesting is blocked). Capture the impl PR URL as `IMPL_PR_URL`. (As on
the full path, the playbook's Step 6.5 runs a post-QA docs sync on the `clean` verdict, before the
PR, folding regenerated docs into the same PR; a docs-content failure WARNs, not blocks.)

Then resolve `MODE`, post the mode-aware Jira comment (B2 below) **before** the loop, and run the
**Loop-after-raise** procedure (above) for the impl PR as the session **tail**
(`<PR_URL>`=`IMPL_PR_URL`, `<PHASE>`=`impl`): `Full Auto` → tail loop **with** the auto-merge hook
(auto-merges on clean → completes the story, then best-effort transitions it to the pipeline done
status); any other mode → tail loop **without** a hook (leave the PR open for human merge). Terminal
action: apply **Session boundary at PR raise**.

### B2 — Complete (comment posted BEFORE the tail loop)

Post the mode-aware comment now — before entering the loop, since the loop is the session's last act
(intent tense; any merge happens inside the loop's clean exit). Run the site guard once before either
branch below:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
```

- **`Full Auto`:**

```bash
acli jira workitem comment create --key STORY_KEY --body "Implementation complete (Full Auto).

PR: IMPL_PR_URL

Small story (≤3pts) — direct implementation path. Driving Copilot review-fix; will auto-merge once review + checks pass, then transition this story to the pipeline done status."
```

- **Any other mode:**

```bash
acli jira workitem comment create --key STORY_KEY --body "Implementation complete.

PR: IMPL_PR_URL

Small story (≤3pts) — direct implementation path. Driven to Copilot-clean; review and merge to develop."
```

**If ASYNC_REVIEW=true** — fire completion event:

```bash
curl -s --retry 3 -X POST http://localhost:9001 \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"phase/complete\",\"params\":{\"storyKey\":\"STORY_KEY\",\"implUrl\":\"IMPL_PR_URL\"},\"id\":1}"
```

---

## Epic orchestration — drive every child story

Entered from **Step 0** when `STORY_KEY` is an **Epic**. Step 0 already reads
`${CLAUDE_PLUGIN_ROOT}/refs/epic-orchestration.md` (explicit path) and follows it in full — E0
through E5b, covering the Epic's AI-Workflow-mode precondition, the dependency-ordered queue, the
per-story loop, HALT-on-failure, and the suspend-primitive protocol. **The single-story path (Step
1 onward, below) never loads this ref.** If the ref is unreadable when Step 0 needs it → STOP with
the missing path; never continue on a half-loaded contract.

---

## Final action — release the session

```text
SDLC_BOUNDARY_ON unset (default)     -> the tail loop owns the single release, exactly as before
SDLC_BOUNDARY_ON set + harness       -> the PHASE releases at PR raise (Session boundary at PR
                                         raise); the re-invoked loop session releases its own slot
SDLC_BOUNDARY_ON set + interactive   -> the tail loop owns the single release, exactly as before
no PR was raised at all              -> run session-complete.sh directly here
```

**Direct release whenever no tail loop ran.** In every case below, run `session-complete.sh` directly
as the very last action, or the slot leaks until the idle timeout:

- the Step 0 unsupported-input-type stop (no session spawned); **and**
- the **epic path** when the epic session itself ends (E0 unset-Epic reject, E1 `GATE=STOP`, E3
  `abort`, E4 HALT, or all children done) — the epic session keeps `SDLC_SESSION_KEY=EPIC_KEY` and
  must release its **own** slot directly here (each child released its own slot via its own tail
  loop); **and**
- the Step 2 missing-points stop, a triage failure, or any early error (no PR raised); **and**
- the **`ASYNC_REVIEW=true`** branches (A1, A2, B-phase), which raise a PR, fire the `phase/*`
  JSON-RPC event, and **stop without looping** — they still need the explicit release.

In those cases run this as the very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for. Outside the worker
(`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run. (Distinct from the `phase/*`
JSON-RPC events, which drive the service state machine; this releases the worker's local concurrency
slot.)

Jira story key (e.g. CER-123):
STORY_KEY
