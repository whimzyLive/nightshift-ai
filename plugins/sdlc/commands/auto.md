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
ITYPE="$(acli jira workitem view STORY_KEY --fields issuetype --json 2>/dev/null \
           | jq -r '.fields.issuetype.name // empty' | tr '[:upper:]' '[:lower:]')"
```

Route on `ITYPE`:

- `story` (or any non-epic *implementable* type your project routes through `/auto` as a single
  story) → **continue to Step 1 below — the single-story flow is UNCHANGED.**
- `epic` → **go to the [Epic orchestration](#epic-orchestration--drive-every-child-story) section
  and do NOT run Steps 1+ for the epic key itself.** Each child story runs its own full `/auto`
  single-story flow in a child session.
- `sub-task` / any other type / an empty/unreadable probe → **STOP** with `unsupported input type`.
  Tell the user: "STORY_KEY is not a Story or Epic (issuetype=`<name>`) — `/auto` drives a single
  story or a whole epic; unsupported input type." Spawn **no** session. Then run the direct
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
   posted before it — see A1/A3/B2 for the per-phase, mode-aware text).
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

Lightweight stories go **straight from triage to implementation** — **no spec, no plan doc, and no
review gate**. There is **no plan-generation step**: the implementation derives its tasks inline from
the Jira story description (exactly as standalone `/impl` does on its lightweight path). This is the
deliberate fast-path for small (≤ threshold-points) stories — the spec/plan ceremony is reserved for
`full` stories (Workflow A).

> **No `docs/superpowers/plans/STORY_KEY.md` is created or required on this path.** A plan doc is
> neither generated (no `tech-lead` dispatch) nor a precondition. If you *want* a recorded plan and a
> review gate, the story should be triaged `full` (raise its story points above the threshold).

### B1 — Implement (direct)

Run the implementation exactly as `${CLAUDE_PLUGIN_ROOT}/commands/impl.md` specifies for `STORY_KEY`: execute
the Principal Engineer playbook (`${CLAUDE_PLUGIN_ROOT}/refs/principal-engineer-playbook.md`) **inline in this
session** with **`LIGHTWEIGHT=true`** — dispatch the domain agents yourself with the `Agent` tool. On its
lightweight path the playbook skips the plan-file STOP and **derives tasks inline from the Jira story**
(Step 2), so no plan doc is needed. Do NOT dispatch a `principal-engineer` subagent (nesting is blocked).
Capture the impl PR URL as `IMPL_PR_URL`.

Then resolve `MODE`, post the mode-aware Jira comment (B2 below) **before** the loop, and run the
**Loop-after-raise** procedure (above) for the impl PR as the session **tail**
(`<PR_URL>`=`IMPL_PR_URL`, `<PHASE>`=`impl`): `Full Auto` → tail loop **with** the auto-merge hook
(auto-merges on clean → completes the story); any other mode → tail loop **without** a hook (leave the
PR open for human merge). The tail loop owns the release.

### B2 — Complete (comment posted BEFORE the tail loop)

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

## Epic orchestration — drive every child story

Entered from **Step 0** when `STORY_KEY` is an **Epic**. The epic session drives every child story
to completion in dependency order, spawning **one child `claude` session per story** and running
exactly **one child live at a time**. Throughout this section `EPIC_KEY` = the epic key passed as
`STORY_KEY`.

The epic session keeps its **own** `SDLC_SESSION_KEY=EPIC_KEY`. Each child it spawns gets
`SDLC_SESSION_KEY=<that child's story key>` — the epic key and every child key are distinct, so the
parent's release sentinel and each child's completion sentinel never collide.

### E0 — Epic precondition: the Epic's AI Workflow mode (`epicFallback`)

Read the **Epic's own** AI Workflow field **once**, at loop start, using the same definitive,
format-stable JQL probe the single-story flow uses for a story's mode (see *Resolving the working
issue's mode*) — applied to `EPIC_KEY`:

```bash
# epicFallback = the Epic's ACTUAL AI Workflow value (e.g. Full Auto / Auto /
# Assisted), or empty if the field is unset/unreadable. It must be a real mode
# string: later sections interpolate <effectiveMode(S)> into operator-facing
# prompts, so a placeholder here would leak into output.
if acli jira workitem search --jql 'key = EPIC_KEY AND "AI Workflow" = "Full Auto"' --fields key 2>/dev/null | grep -qw EPIC_KEY; then
  epicFallback="Full Auto"
elif acli jira workitem search --jql 'key = EPIC_KEY AND "AI Workflow" is not EMPTY' --fields key 2>/dev/null | grep -qw EPIC_KEY; then
  # Set but not Full Auto — read the field's real value (Auto / Assisted / …)
  # so effectiveMode resolves to a genuine mode string rather than a placeholder.
  epicFallback="$(acli jira workitem view EPIC_KEY --fields 'AI Workflow' --json 2>/dev/null \
                    | jq -r '.fields["AI Workflow"].value // .fields["AI Workflow"].name // .fields["AI Workflow"] // empty')"
  [ -z "$epicFallback" ] && epicFallback="Auto"   # set-but-unreadable name ⇒ safe gated default (any non-Full-Auto value gates)
else
  epicFallback=""                   # unset OR unreadable
fi
```

**If `epicFallback` is empty (the field is unset)** → **REJECT**: post a comment on the **Epic**
explaining that an AI Workflow mode must be set before automation, and exit **without spawning any
session**:

```bash
acli jira workitem comment create --key EPIC_KEY --body "Cannot start epic automation: the AI Workflow field is not set on this Epic.

Set the Epic's AI Workflow to one of Full Auto / Auto / Assisted (it becomes the default mode for every child story that does not set its own), then re-run /auto EPIC_KEY."
```

Then run the direct `session-complete.sh` release (see **Final action**) and exit. (An unreadable
probe is treated as unset — the safe default is to refuse to spawn anything rather than guess a mode.)

### E1 — Build the dependency-ordered queue

Run the queue builder as **one** statically-analysable invocation (all `acli`/`jq`/loops live inside
the script, mirroring `dep-gate.sh`):

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/epic-queue.sh EPIC_KEY
```

Parse its greppable output:

- `ORDER=<k1 k2 …>` — the stories in execution order: a story appears only after every sibling that
  `Blocks` it (the feature-spec dependencies, encoded in the Jira `Blocks` graph). Independent
  stories are tie-broken by Jira `created ASC`.
- one `<key> BLOCKERS=<…>` line per story (informational).
- `GATE=PASS` (exit 0) → proceed with `ORDER`.
- `GATE=STOP` (exit 1) → the builder hit an acli failure **or a dependency cycle** (its `REASON=`
  line names the cycle keys). **Do not spawn anything** — surface the `REASON` to the user, run the
  direct `session-complete.sh` release, and exit.

### E2 — Per-story loop

For each story `S` in `ORDER`, in order, run the steps below. Maintain a `cursor` (see E5) so the
epic is resumable. Exactly **one** child session is live at any moment.

**E2a — Idempotent skip (re-run safety).** Before spawning, probe `S`'s Jira status definitively
(format-stable field read — `acli jira workitem view S --fields status --json` then read
`.fields.status.name`; do not scrape rendered text). If it already equals the **pipeline done
status** (the consuming repo's terminal status — read from `.claude/project/project-context.md`,
the same done status the pipeline already uses; add no new terminal status here) → **skip `S`
without spawning a session** and advance to the next story. This makes re-running `/auto EPIC_KEY`
idempotent: already-finished stories are passed over.

**E2b — Decide whether `S` is gated.** Resolve `S`'s effective mode:

- `storyMode(S)` = `S`'s own AI Workflow value via the single-story JQL probe (`Full Auto` /
  non-Full-Auto / unset).
- `effectiveMode(S) = storyMode(S) ?? epicFallback` — the story's own mode if it has one, else the
  Epic's `epicFallback`.
- `gated(S) := effectiveMode(S) != "Full Auto"`.

`Full Auto` is the **only** non-gated value. `Auto`, `Assisted`, and any unreadable mode probe ⇒
**gated** (the safe default — a transient read error must never silently un-gate a story).

**E2c — Spawn the child session and wait for its sentinel.** Spawn exactly one child:

```bash
SDLC_SESSION_KEY=S claude --name S --dangerously-skip-permissions
```

Drive it with the single-story command `/auto S` (a fresh single-story run — it re-enters Step 0,
detects `S` as a Story, and runs Steps 1+ unchanged). Because the child's environment carries
`SDLC_SESSION_KEY=S`, the child's final `session-complete.sh` emits the **keyed** sentinel on its own
output stream:

- bare: `<<<SDLC_SESSION_COMPLETE:S>>>`
- with PR: `<<<SDLC_SESSION_COMPLETE:S|PR=URL>>>`

(KEY is exactly `S`; the terminator is exactly `>>>`.) **Watch the child's stream for that exact
sentinel keyed on `S`.** On seeing it, the child has succeeded for this phase — tear the child
session down and continue (handle gating in E3, then advance to the next story).

### E3 — Gate handling (suspend primitive)

After a child completes (sentinel seen), if `gated(S)` the epic must **suspend** before starting the
next story — the gated story's PR needs human review + merge first. Suspension goes through a single
documented seam (see **E5 — Suspend-primitive protocol**), and `resolveImpl()` picks the path: the
**worker alternate** emits the `<<<SDLC_EPIC_GATED:…>>>` marker and yields to the worker host (E5a/E5b),
the **interactive default** (implemented here, unchanged) is:

The child has **already** posted its own mode-aware Jira gate comment with the PR link (existing
single-story behaviour — unchanged; the epic adds **no** new Jira comment format). The parent epic
session then **blocks and prompts on stdout**:

```
Story S is gated (mode=<effectiveMode(S)>). PR: <url>. Review + merge, then type 'continue' to proceed to <nextStory>, or 'abort' to stop the epic.
```

- operator types **`continue`** → resume **in-process** at the next story (advance the cursor, loop
  back to E2 for `nextStory`).
- operator types **`abort`** → **clean stop**: no failure is recorded, the epic simply ends here. Run
  the direct `session-complete.sh` release and exit. (Re-running `/auto EPIC_KEY` later resumes —
  E2a skips every already-done story and picks up where the abort left off.)

If `gated(S)` is **false** (`effectiveMode(S) == "Full Auto"`): the child already drove its PR to
auto-merge via its own tail loop — **no suspend**, just advance straight to the next story. The
all-Full-Auto epic is therefore **emergent**: no story is ever gated ⇒ the suspend primitive is
never invoked ⇒ the whole epic runs to completion in this single epic session, hands-free.

### E4 — HALT on child failure

A child **succeeds** iff it emits its `<<<SDLC_SESSION_COMPLETE:S…>>>` sentinel. If the child instead
exits non-zero, errors out, or hits its **idle timeout with no sentinel**, treat it as a **failure**
and **HALT the whole epic immediately** — do **not** skip the story and do **not** continue to the
next one:

1. Post a Jira comment on the **failed story `S`** noting the epic run halted on it and why (e.g.
   `child session for S failed: <reason>` — non-zero exit / error / idle-timeout-no-sentinel).
2. Surface an **epic-level halt on stdout** naming the failed story and the reason.
3. Run the direct `session-complete.sh` release and exit.

The epic stays **resumable**: a later `/auto EPIC_KEY` skips every terminal story (E2a) and resumes
at the still-unfinished failed story. An idle-timeout-with-no-sentinel is **always** a HALT, never a
silent skip — a child that went quiet without signalling completion has *not* succeeded.

### E5 — Suspend-primitive protocol (the seam)

The gate-suspension point in E3 is a documented **prose protocol** (a seam), not an exported type.
It is defined by two operations the epic loop calls at a gated story:

- **`suspendForGate(epicKey, storyKey, cursor)`** — persist the resume state at the **next** story,
  then either **block-and-resume in-process** (the interactive default — wait at the stdout prompt,
  resume the loop on `continue`) **or** **emit-marker-and-yield** (the worker alternate — print the
  gated marker on stdout and hand control to the worker host, which persists the cursor, releases its
  slot, and tears the session down). Either way the epic resumes at the cursor's next story.
- **`resolveImpl()`** — selects which `suspendForGate` implementation is active: the **worker
  alternate** when a worker-substrate marker is present (e.g. `SDLC_SESSION_KEY` is set **and** a
  worker environment marker indicates the session is running under that substrate), the **interactive
  default** otherwise.

`cursor` carries: `epicKey`, the **next** story key (and its index into `ORDER`), and the gated
story's PR URL. It is the single source of resume truth, so a resumed epic continues at exactly the
story after the gate.

#### E5a — The two suspend paths

`resolveImpl()` chooses **exactly one** of these at a gated story; they are mutually exclusive:

- **Interactive default** (no worker-substrate marker) — **unchanged**: the E3 stdout prompt + the
  in-process `continue`/`abort` resume. The session stays open and blocks for an operator. No marker
  is emitted on this path.
- **Worker alternate** (`resolveImpl()` saw the worker-substrate marker) — the loop does **not**
  block-and-prompt. Instead it emits the single-line **epic-gated marker** (below) on stdout and
  **yields control to the worker host**. The worker host (the substrate that spawned this session)
  watches the session's stdout for that marker, persists the resume cursor from its fields, releases
  the session's concurrency slot, and tears the session down. The epic later resumes — driven by the
  worker host re-spawning `/auto EPIC_KEY` — at exactly `nextIndex` into `ORDER` (E2a re-skips every
  already-done story, so the marker is an optimisation/handoff signal, never the sole source of
  resume truth).

#### E5b — Epic-gated marker contract (worker-alternate path only)

On the worker-alternate path, at a gated story, the loop emits **exactly** this single line on
stdout (and nothing block-and-prompt on this path):

```
<<<SDLC_EPIC_GATED:<epicKey>|story=<gatedStoryKey>|nextIndex=<N>|order=<b64>|fallback=<mode>|pr=<URL>>>>
```

This mirrors the `<<<SDLC_SESSION_COMPLETE:…>>>` sentinel convention: the opening token is
`<<<SDLC_EPIC_GATED:` and the terminator is **exactly** `>>>`. Field sourcing:

- `<epicKey>` — the Epic key (`EPIC_KEY`, the epic this loop is driving — `cursor.epicKey`).
- `<gatedStoryKey>` — the story the epic is suspended at: the just-completed gated story `S`
  (`gated(S)` is true; this is the story whose PR needs review + merge).
- `<N>` — the **0-based** index into `ORDER` of the **next** story to run after the gate
  (`cursor`'s next-story index; if `S` is the last entry in `ORDER` there is no next story — the epic
  is done and this marker is not emitted).
- `<b64>` — **base64** of the JSON array of the full ordered story-key list, i.e. `base64(JSON)` of
  the `ORDER` list emitted by `epic-queue.sh` (e.g. `["KEY-1","KEY-2","KEY-3"]`). Carrying the whole
  order lets the worker host reconstruct the queue without re-deriving it.
- `<mode>` — the epic's resolved **AI Workflow fallback mode** (the fallback applied when a story has
  no explicitly readable mode; see E2b mode resolution).
- `<URL>` — the gated story's **PR URL** (`cursor`'s PR URL — the same link the child posted on its
  Jira gate comment).

The worker host parses these fields to persist the cursor + resume later; the plugin's only
obligation on this path is to emit the line **verbatim** and then yield. The substrate itself lives
outside this plugin and is intentionally not named here — the marker line is the entire contract the
plugin exposes to it.

> **This plugin ships the interactive default working** (the E3 stdout prompt + in-process resume).
> A worker substrate registers the alternate `suspendForGate` behind this same seam **without
> changing this command** — `resolveImpl()` picks it up from the environment marker. That substrate
> lives outside this plugin and is intentionally not referenced here; the seam is all the plugin
> needs to know about.

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
