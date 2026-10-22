---
description: Full SDLC automation for a Jira story. Assesses the story (a label probe when it is already AI-Ready), applies the shared triage protocol (refs/triage.md, inline), and routes a `full` story through spec-in-session → your approval → implementation, shipping spec and code in ONE PR, or a `lightweight` story (<= threshold pts, inclusive) straight to implementation. Full Auto waits for checks and merges; otherwise the PR is left for you. Copilot review is advisory. Pass --async-review for service-driven execution where JSON-RPC events replace the human merge.
---

Parse $ARGUMENTS:

- `STORY_KEY` = $ARGUMENTS with `--async-review` stripped (e.g. `CER-123 --async-review` → `CER-123`)
- `ASYNC_REVIEW` = `true` if `--async-review` present in $ARGUMENTS, else `false`

## Step 0 — Detect the input type (Story vs Epic)

`/auto` takes a Story/Bug key or an Epic key. Probe the structured `issuetype.name` — never scrape
rendered `acli` text:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
ITYPE="$(acli jira workitem view STORY_KEY --fields issuetype --json 2>/dev/null \
           | jq -r '.fields.issuetype.name // empty' | tr '[:upper:]' '[:lower:]')"
```

- `story` **or** `bug` (any non-epic implementable type) → **Step 1** (single-story flow). **Retain
  `ITYPE`** — it feeds the inline triage (zero extra Jira I/O) and the Step-2 missing-points bypass.
  A `bug` triages `WORK_KIND=defect` + `TRIAGE=lightweight` → Workflow B (systematic debugging).
- `epic` → **read `${CLAUDE_PLUGIN_ROOT}/refs/epic-orchestration.md` (explicit path) and follow it —
  never Steps 1+ for the epic key.** Unreadable → **STOP** with the missing path. The single-story
  path never reads this ref.
- `sub-task` / any other type / empty probe → **STOP**: "STORY_KEY is not a Story, Bug, or Epic
  (issuetype=`<name>`) — unsupported input type." Spawn nothing; bare release (**Final action**).

## Step 1 — Assess

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/assess-ready.sh STORY_KEY   # AI_READY=yes|no|unknown, SPEC_APPROVED=yes|no|unknown
```

- `AI_READY=yes` → `QUALITY=ok`; **no dispatch** — the story was already refined. Points come from
  the Step-2 triage.
- `AI_READY=no|unknown` → dispatch the `scrum-master` agent in **Mode 3 (Auto-Assess)** with
  `STORY_KEY`; it returns exactly `QUALITY=ok|triaged` and `STORY_POINTS=N|missing`.
- Keep `SPEC_APPROVED` for Workflow A (`unknown` counts as not approved).
- The two lines ARE the label answer — never re-check labels with `acli … view --json` (it renders
  `labels` null even when set; `refs/jira-fetch.md`).

## Step 2 — Route

- **Bug** (`ITYPE == bug`) → skip the missing-points stop below; a Bug routes without points.
- **Missing points** (non-Bug, `STORY_POINTS=missing` from Step 1 or from the triage below) → **stop**:
  "Story points not set on STORY_KEY — set them in Jira, then re-run `/auto STORY_KEY`."

Apply `${CLAUDE_PLUGIN_ROOT}/refs/triage.md` **INLINE**, passing `ITYPE` as `<ISSUE_TYPE>`. Capture
`WORK_KIND=defect|feature` (threaded into the impl phase — debugging variant + branch prefix) and
`TRIAGE`. Triage STOPs without its `WORK_KIND=`/`TRIAGE=`/`STORY_POINTS=` block (e.g. an `acli`
failure) → **STOP** and surface it; never guess a route. **Never invoke the `/triage` command** — its
final action releases the worker slot mid-`/auto`; apply the ref.

- `TRIAGE=full` → **Workflow A** (approved spec, then impl — one PR)
- `TRIAGE=lightweight` → **Workflow B** (direct impl, tasks from the story)

---

## Tail after PR raise (shared by A2, B1)

No review loop runs on the PR: QA already reviewed it in session, and Copilot (requested at PR
creation) is **advisory** — its comments never block the merge.

1. **Resolve `MODE`** — `eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-ai-workflow-mode.sh STORY_KEY)"`
   (ladder: `${CLAUDE_PLUGIN_ROOT}/refs/ai-workflow-mode-resolution.md`). Only `Full Auto` merges;
   empty or a read error takes the human-merge path.
2. **Resolve `DONE_STATUS`** — the `Pipeline done status` row of `.claude/project/project-context.md`.
3. **Post the Jira comment FIRST** — `jira-site-guard.sh` once; guard fails → **STOP**, release with
   the PR URL (nothing may write to a possibly-wrong Jira):
   - `Full Auto` (not async): `Implementation complete (Full Auto). PR: <PR_URL>. <NOTE> Waiting for checks, then auto-merging and moving the story to <DONE_STATUS>. Copilot review is advisory.`
   - otherwise, and every `ASYNC_REVIEW=true` run: `Implementation complete. PR: <PR_URL>. <NOTE> Ready for review and merge (Copilot review is advisory).`
   - `<NOTE>`: A2 → `Includes the approved spec.`; B1 → `Small story — direct implementation path.`
4. **`<NEXT>`** — `Full Auto` → `Run bash ${CLAUDE_PLUGIN_ROOT}/scripts/auto-merge-pr.sh --wait-checks <PR_URL> STORY_KEY "<DONE_STATUS>"; on a non-zero exit comment STORY_KEY per /sdlc:auto Tail step 5, then run session-complete.sh <PR_URL>.`
   Any other mode → no `<NEXT>`: skip the boundary below and release with the PR URL.
5. **Merge outcome** (whoever runs `<NEXT>` posts it): exit 0 → nothing more; exit 1 → `Not merged:
   <PR_URL> — a check is failing or branch protection refused the merge. Fix it, then merge.`;
   exit 3 → `Checks still running on <PR_URL> — merge once they pass.`; any other exit → `Could not
   merge <PR_URL> automatically (gh/API error) — merge it manually.` The PR stays open on every
   non-zero exit, and the run still releases normally.

Then apply **Session boundary at PR raise** to `<NEXT>`.

### Session boundary at PR raise

The top-level session re-bills every resident tool result on every later turn (NA-91), so the tail
may run as a NEW session. `<NEXT>` is the FULL tail line, printed verbatim, never reconstructed.

```text
SDLC_BOUNDARY_ON unset                        -> run <NEXT> inline as today's tail, then release
                                                  with the PR URL   # DEFAULT: unchanged behaviour
SDLC_BOUNDARY_ON set + SDLC_SESSION_KEY set   -> print `<<<SDLC_NEXT_INVOCATION:<NEXT>>>>`, run
                                                  `session-complete.sh <PR_URL>`, STOP   # harness
                                                  re-invokes <NEXT> fresh
SDLC_BOUNDARY_ON set + SDLC_SESSION_KEY unset -> interactive: print <NEXT>, then run it inline,
                                                  then release with the PR URL
```

First-match-wins; the boundary is **opt-in**. **A harness must adopt `SDLC_NEXT_INVOCATION` before
`SDLC_BOUNDARY_ON` is ever set** — otherwise Full Auto PRs raised under it never merge.

---

## Workflow A — `TRIAGE=full`

A full story is implemented only from a spec a human approved in session. Spec and code ship in
**one** PR on `feat/STORY_KEY`; there is no spec PR and no plan.

### A0 — Is the spec approved?

```bash
git fetch origin --quiet   # <BASE-BRANCH> := the `Base branch` row of .claude/project/project-context.md
SPEC_ON_BRANCH=$(git cat-file -e origin/feat/STORY_KEY:docs/superpowers/specs/STORY_KEY.md 2>/dev/null && echo yes || echo no)
LEGACY=$( { git cat-file -e origin/<BASE-BRANCH>:docs/superpowers/specs/STORY_KEY.md 2>/dev/null \
  || test -f docs/superpowers/plans/STORY_KEY.md; } && echo yes || echo no)
```

`SPEC_APPROVED=yes` (Step 1) **and** `SPEC_ON_BRANCH=yes` → **A2**. A story already through the old
flow is approved too: `LEGACY=yes` (its spec PR merged under the old flow, or a plan doc) → **A2**
without asking again. Otherwise log the requirement once —
label `Spec-Required` and comment `Needs an approved spec before implementation.` — then:

- `SDLC_SESSION_KEY` unset (a person is here) → **A1**, then **A2** in this same run.
- `SDLC_SESSION_KEY` set (unattended — nobody can approve) → **STOP**, bare release. An epic gets
  its specs approved before its unattended run (`refs/epic-orchestration.md` E0b).

### A1 — Spec, in this session

Apply `${CLAUDE_PLUGIN_ROOT}/commands/spec.md` Steps 1–4 **inline** (never its Final action): write
the spec, settle open questions with `AskUserQuestion` (defaults first), get an explicit approval,
commit it to `feat/STORY_KEY`, label `Spec-Approved`. Not approved → **STOP** here, bare release.

### A2 — Implement (single PR with the spec)

Run `${CLAUDE_PLUGIN_ROOT}/commands/impl.md`'s implementation for `STORY_KEY`: execute
`${CLAUDE_PLUGIN_ROOT}/refs/principal-engineer-playbook.md` **inline in this session** with
`LIGHTWEIGHT=false` and the Step-2 `WORK_KIND`, on `feat/STORY_KEY` (the branch `/spec` created; a
legacy story gets a fresh one) — its tasks come from the spec's `## Implementation tasks`. Dispatch the domain agents yourself; never a
`principal-engineer` subagent (nesting is blocked). Capture `IMPL_PR_URL`; the PR carries the spec
commit and the code. Then the **Tail after PR raise** with `<NOTE>` for A2.

## Workflow B — `TRIAGE=lightweight`

### B1 — Implement (direct)

No spec and no plan: execute the Principal Engineer playbook **inline** with `LIGHTWEIGHT=true` and
the Step-2 `WORK_KIND` (`defect` → systematic-debugging on `fix/STORY_KEY`; `feature` →
`feat/STORY_KEY`); tasks derive from the story. Capture `IMPL_PR_URL`, then the **Tail after PR
raise** with `<NOTE>` for B1.

## ASYNC_REVIEW=true

After the impl PR is raised (A2 or B1), post the Step-3 comment, fire both events, and stop
without the tail — the service owns the merge. Release with the PR URL.

```bash
curl -s --retry 3 -X POST http://localhost:9001 -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"phase/pr_raised\",\"params\":{\"storyKey\":\"STORY_KEY\",\"type\":\"impl\",\"url\":\"IMPL_PR_URL\"},\"id\":1}"
curl -s --retry 3 -X POST http://localhost:9001 -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"phase/complete\",\"params\":{\"storyKey\":\"STORY_KEY\",\"implUrl\":\"IMPL_PR_URL\"},\"id\":2}"
```

**Service contract change:** there is no spec or plan PR any more, so `type=spec` / `type=plan`
events are never sent. An unattended run that needs a spec approval takes the A0 STOP with no event
— the story's `Spec-Required` label is the signal; re-invoke after `/spec STORY_KEY` approves it.

## Epic orchestration — drive every child story

Entered from **Step 0** for an Epic: `${CLAUDE_PLUGIN_ROOT}/refs/epic-orchestration.md` E0–E5b
(mode precondition, spec preflight, dependency-ordered queue, per-story loop, HALT-on-failure,
suspend protocol). The single-story path never loads it.

---

## Final action — release the session

first-match-wins:

```text
ASYNC_REVIEW=true, PR raised      -> release WITH the PR URL (no tail)
PR raised, tail ran or no <NEXT>  -> release WITH the PR URL (Session boundary rows above)
no PR was raised at all           -> bare release
```

**Bare** — Step 0 unsupported type; the epic session's own end (E0 reject, E0b, E1 `GATE=STOP`, E3
`abort`, E4 HALT, or all children done — the epic keeps `SDLC_SESSION_KEY=EPIC_KEY` and releases its
own slot here); the Step-2 missing-points stop; A0/A1 stops; any early error:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

**With the PR URL:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh <PR_URL>
```

It prints the completion signal the automation worker watches for; outside the worker
(`SDLC_SESSION_KEY` unset) it is a silent no-op. (Distinct from the `phase/*` JSON-RPC events.)

Jira story key (e.g. CER-123):
STORY_KEY
