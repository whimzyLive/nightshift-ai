---
description: Full SDLC automation for a Jira story. Quality-assesses and triages if needed, then delegates the complexity decision to the shared triage protocol (refs/triage.md, applied inline) and routes a `full` story through the two-phase spec → review-gate → plan+impl-single-PR flow, or a `lightweight` story (<= threshold pts, inclusive) straight to implementation. Posts Jira comments at each gate with clickable PR links. Pass --async-review for non-blocking service-driven execution where JSON-RPC events replace the human confirmation gate.
---

Parse $ARGUMENTS:
- `STORY_KEY` = $ARGUMENTS with `--async-review` stripped (e.g. `CER-123 --async-review` → `CER-123`)
- `ASYNC_REVIEW` = `true` if `--async-review` present in $ARGUMENTS, else `false`

## Step 1 — Assess

Dispatch the `scrum-master` agent in **Mode 3 (Auto-Assess)** with `STORY_KEY`.

Wait for its response — it returns exactly:
```
QUALITY=ok|triaged
STORY_POINTS=N|missing
```

## Step 2 — Route

**First, short-circuit on missing points from Step 1.** If scrum-master returned
`STORY_POINTS=missing`, **stop here** — do NOT run the triage step (it would only re-fetch Jira and
return `full` + a warning, and a transient triage `acli` failure could then leave `/auto` unable
to route despite Step 1 having already succeeded). Tell the user: "Story points not set on
STORY_KEY — story has been triaged. Set story points in Jira, then re-run `/auto STORY_KEY`."

Otherwise, run the triage step by **applying `${CLAUDE_PLUGIN_ROOT}/refs/triage.md` INLINE** (in
this same session) and route on its `TRIAGE` outcome — the single shared definition of the
lightweight/full decision (default threshold `<= 3` points ⇒ lightweight, inclusive; configurable
per-repo). If the triage step STOPs **without** emitting the required `TRIAGE=`/`STORY_POINTS=`
block (e.g. an `acli` auth/DNS failure), **STOP** and surface that error — do not guess a route.

> **Do NOT invoke the `/triage` slash command here.** `/triage` is a top-level command whose final
> action runs `session-complete.sh`, which (under the automation harness) emits the session-complete
> sentinel and releases this worker slot — mid-`/auto`, before plan/impl have run. `/auto` owns the
> single release at the very end. Apply the **ref** inline; never call the **command** from inside
> `/auto`. (`refs/triage.md` is pure routing logic and emits no sentinel.)

- `TRIAGE=full` → **Workflow A** (Phase 1: spec + review gate → Phase 2: plan + impl in a single PR)
- `TRIAGE=lightweight` → **Workflow B** (direct impl, no spec/plan review gate)

(Step 1's scrum-master `STORY_POINTS=N|missing` gates the `missing` stop **before** the triage step
runs; the complexity routing itself is delegated to the shared `refs/triage.md` protocol — applied
inline, not the `/triage` command — so `/auto` and `/impl` share one definition.)

---

## Loop-after-raise + mode-conditioned terminal action (shared by A1, A2, B2)

Every phase that raises a PR drives the Copilot review-fix loop on it **before** the phase finishes,
then takes a terminal action that depends on the story's mode. A1, A2, and B2 below each invoke this
procedure with their just-raised `<PR_URL>` and a `<PHASE>` of `spec` (advances to Phase 2 on
merge), `plan+impl`, or `impl` (completes the story on merge).

### Resolving the working issue's mode

The terminal action (auto-merge vs leave for a human) depends on the story's AI workflow mode. Do
**not** parse `acli workitem view` text output — that format is not stable across acli
versions/flags, and a parse miss would silently disable Full Auto. Instead probe **definitively**
with a JQL match (the repo's established custom-field-read pattern — see `refs/jira-fetch.md`), so
auto-merge is enabled **only** when Jira itself confirms the field equals `Full Auto`:

```bash
# Definitive, format-agnostic Full-Auto check: ask Jira directly whether STORY_KEY matches.
if acli jira workitem search --jql 'key = STORY_KEY AND "AI Workflow" = "Full Auto"' --fields key 2>/dev/null | grep -qw STORY_KEY; then
  MODE="Full Auto"
else
  MODE="other"   # Auto / Assisted / unset / unreadable — all take the human-merge path
fi
```

`MODE="Full Auto"` is the **only** value that enables auto-merge. Any other outcome (`Auto`,
`Assisted`, unset, or a JQL/auth error that yields no match) → the **human-merge** path. Defaulting
to the human path is the safe failure mode: a transient read error must never trigger an unattended
merge. (The `"AI Workflow"` field name is the consuming repo's single-select; the JQL match is
case- and format-stable, unlike scraping view output.)

### The procedure (the loop is the tail — it owns the release)

The loop is the phase's **tail**, exactly like the standalone commands: hand it to the native
`/loop` driving `sdlc:loop`. For a **Full Auto** story, inject the auto-merge as the loop's
`--on-clean` hook so it runs at the loop's rule-4 clean exit — the loop stays mode-agnostic and just
runs the hook. The loop owns the single `session-complete`; `/auto` does **not** release separately.

1. **Resolve `MODE`** (see above) — this decides whether an `--on-clean` hook is attached.
2. **Post the phase's Jira comment FIRST** (the loop is the session's last act, so the comment is
   posted before it — see A1/A3/B3 for the per-phase, mode-aware text).
3. **Run the loop as the tail:**
   - **`MODE` = `Full Auto`** → attach the auto-merge hook; on the loop's clean exit it auto-merges
     `<PR_URL>`, whose merge event advances the pipeline (`<PHASE>=spec` → resumes Phase 2;
     `plan+impl`/`impl` → completes the story):
     ```bash
     /loop /sdlc:loop <PR_URL> --on-clean "bash ${CLAUDE_PLUGIN_ROOT}/scripts/auto-merge-pr.sh <PR_URL>"
     ```
   - **Any other mode** → no hook; the loop just drives the PR to Copilot-clean and stops for a human
     merge:
     ```bash
     /loop /sdlc:loop <PR_URL>
     ```

The loop drives review-fix to convergence (or halts on review-fix-blocked / CI-red / idle-budget),
then releases via its own Final action. On a non-clean halt the `--on-clean` hook does **not** run
(no merge) — the PR stays open and the halt reason is surfaced. If the hook itself fails (branch
protection, conflict), the loop surfaces it and the PR stays open.

> **Fallback** — if the harness cannot self-invoke the native `/loop` from inside `/auto`: drive
> `sdlc:loop`'s pass-cycle via `ScheduleWakeup` yourself and run the resolved `--on-clean` command at
> the rule-4 clean exit, before the single release. Same effect — the loop is the last thing the
> session does, and `/auto` adds no separate release.

`sdlc:loop` stays mode-agnostic — it only drives review-fix and runs whatever `--on-clean` hook it
was handed; `/auto` decides (via `MODE`) whether to attach the auto-merge hook.

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
`<PHASE>`=`spec`). The comment is posted **before** the loop (the loop is the last act):

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

The **tail loop owns the release** — do not run `session-complete.sh` here. Do **not** proceed to A2
in this run; Phase 2 is resumed by the spec-PR merge (human, or the Full-Auto auto-merge) as a fresh
`/auto STORY_KEY` invocation (A0 detects the merged spec).

---

### A2 — Plan + Implement (Phase 2, single PR)

**Precondition:** spec is merged to `develop` (verified by A0). Plan and implementation share **one branch** and ship as **one PR** — there is no separate plan PR.

1. **Branch.** Create the implementation branch `feat/STORY_KEY` off `develop`.
2. **Plan.** Dispatch the `tech-lead` agent for `STORY_KEY` to produce `docs/superpowers/plans/STORY_KEY.md` as instructed in `${CLAUDE_PLUGIN_ROOT}/commands/plan.md`, but **commit the plan doc onto `feat/STORY_KEY`** — do **not** create a separate plan branch or plan PR. (Same plan content as `/plan`; only the delivery target changes.)
3. **Implement.** Run the implementation exactly as `${CLAUDE_PLUGIN_ROOT}/commands/impl.md` specifies for `STORY_KEY`: execute the Principal Engineer playbook (`${CLAUDE_PLUGIN_ROOT}/refs/principal-engineer-playbook.md`) **inline in this session** — dispatch the domain agents yourself with the `Agent` tool, working on the **existing `feat/STORY_KEY` branch** (do not create a new branch). Do NOT dispatch a `principal-engineer` subagent (nesting is blocked; it cannot dispatch domain agents).
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
   hook (auto-merges on clean → the plan+impl PR landing on `develop` **completes** the story); any
   other mode → tail loop **without** a hook (leave open for human merge). The tail loop owns the
   release.

### A3 — Complete (comment posted BEFORE the tail loop)

Post the mode-aware comment now — before the loop, since the loop is the session's last act (intent
tense; any merge happens inside the loop's clean exit):

- **`Full Auto`:**
  ```bash
  acli jira workitem comment create --key STORY_KEY --body "Plan and implementation complete (Full Auto).

PR: IMPL_PR_URL

Single PR contains the implementation plan and code. Driving Copilot review-fix; will auto-merge once review + checks pass. Spec was merged separately."
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

### B1 — Plan (lightweight)

Dispatch the `tech-lead` agent for `STORY_KEY` with `LIGHTWEIGHT=true`.

The tech-lead will derive tasks from the story description directly, create `docs/superpowers/plans/STORY_KEY.md`, and commit it to `develop` — no branch, no PR.

Wait for completion. Capture the returned plan file path.

### B2 — Implement

Run the implementation exactly as `${CLAUDE_PLUGIN_ROOT}/commands/impl.md` specifies for `STORY_KEY`: execute
the Principal Engineer playbook (`${CLAUDE_PLUGIN_ROOT}/refs/principal-engineer-playbook.md`) **inline in this
session** — dispatch the domain agents yourself with the `Agent` tool. Do NOT dispatch a
`principal-engineer` subagent (nesting is blocked). Capture the impl PR URL as `IMPL_PR_URL`.

Then resolve `MODE`, post the mode-aware Jira comment (B3 below) **before** the loop, and run the
**Loop-after-raise** procedure (above) for the impl PR as the session **tail**
(`<PR_URL>`=`IMPL_PR_URL`, `<PHASE>`=`impl`): `Full Auto` → tail loop **with** the auto-merge hook
(auto-merges on clean → completes the story); any other mode → tail loop **without** a hook (leave the
PR open for human merge). The tail loop owns the release.

### B3 — Complete (comment posted BEFORE the tail loop)

Post the mode-aware comment now — before entering the loop, since the loop is the session's last act
(intent tense; any merge happens inside the loop's clean exit):

- **`Full Auto`:**
  ```bash
  acli jira workitem comment create --key STORY_KEY --body "Implementation complete (Full Auto).

PR: IMPL_PR_URL

Small story (≤3pts) — direct implementation path. Driving Copilot review-fix; will auto-merge once review + checks pass."
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

## Final action — release the session

> **In the normal path the TAIL LOOP owns the single release.** Each routed phase ends by running
> `/loop /sdlc:loop <PR> [--on-clean …]` as its tail (the shared procedure); that loop's own Final
> action emits the single `session-complete`. So every phase `/auto` delegates — triage (inline from
> `refs/triage.md`), spec/plan (the agents), impl (the playbook inline), and the loop-after-raise
> itself — must NOT emit its own `session-complete`. After a phase has handed off to the tail loop,
> `/auto` runs **nothing** further — running `session-complete.sh` again would be a double release.
> (A Full-Auto auto-merge of the spec PR resumes Phase 2 as a *separate* `/auto` invocation with its
> own tail-loop release — not a nested one.)

**Direct release whenever no tail loop ran.** The tail loop owns the release only on the paths that
actually run it (the `ASYNC_REVIEW=false` phase paths above). In **every other case where no tail
loop executed**, run `session-complete.sh` directly as the very last action, or the slot leaks until
the idle timeout:

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
