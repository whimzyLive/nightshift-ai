---
description: Full SDLC automation for a Jira story. Quality-assesses and triages if needed, then delegates the complexity decision to /triage and routes a `full` story through the two-phase spec → review-gate → plan+impl-single-PR flow, or a `lightweight` story (<= threshold pts, inclusive) straight to implementation. Posts Jira comments at each gate with clickable PR links. Pass --async-review for non-blocking service-driven execution where JSON-RPC events replace the human confirmation gate.
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
`STORY_POINTS=missing`, **stop here** — do NOT call `/triage` (it would only re-fetch Jira and
return `full` + a warning, and a transient `/triage` `acli` failure could then leave `/auto` unable
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

(Step 1's scrum-master `STORY_POINTS=N|missing` gates the `missing` stop **before** any `/triage`
call; the complexity routing itself is delegated to `/triage` so `/auto` and `/impl` share one
definition.)

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

**If ASYNC_REVIEW=false** — post the Jira comment, surface the PR, then **stop**:
```bash
acli jira workitem comment create --key STORY_KEY --body "Spec PR ready for review.

Spec PR: SPEC_PR_URL

Review and merge to develop, then re-run /auto STORY_KEY to generate the plan and implementation in a single PR."
```

Tell the user:

> Spec PR raised. Review and merge it to `develop`, then re-run `/auto STORY_KEY` — plan and implementation will be generated together in a single PR.

Do **not** proceed to A2 in this run. The next `/auto STORY_KEY` invocation detects the merged spec (A0) and runs Phase 2.

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

### A3 — Complete

Post Jira comment with the single PR URL from A2:
```bash
acli jira workitem comment create --key STORY_KEY --body "Plan and implementation complete.

PR: IMPL_PR_URL

Single PR contains the implementation plan and code. Spec was reviewed and merged separately."
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

### B3 — Complete

Post Jira comment with impl PR URL from B2:
```bash
acli jira workitem comment create --key STORY_KEY --body "Implementation complete.

PR: IMPL_PR_URL

Small story (≤3pts) — direct implementation path."
```

**If ASYNC_REVIEW=true** — fire completion event:
```bash
curl -s --retry 3 -X POST http://localhost:9001 \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"phase/complete\",\"params\":{\"storyKey\":\"STORY_KEY\",\"implUrl\":\"IMPL_PR_URL\"},\"id\":1}"
```

---

## Final action — release the session (required)

> **This is the ONE and ONLY session release for the whole `/auto` run.** Every phase `/auto`
> delegates — triage (applied inline from `refs/triage.md`), spec/plan (the `solutions-architect` /
> `tech-lead` agents), and impl (the Principal Engineer playbook run inline) — must NOT run its own
> command's `session-complete.sh`. `/auto` reaches this final action exactly once, at the very end,
> and that single emit releases the worker slot. A nested release would free the slot mid-run.

After the routed workflow above is fully complete (Workflow A Phase 1 stop, A3, or B3 — whichever this run reached) and all Jira comments / JSON-RPC events have been sent, run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run. Note: this is distinct from the `phase/*` JSON-RPC events (those drive the service state machine); this signal releases the worker's local concurrency slot.

Jira story key (e.g. CER-123):
STORY_KEY
