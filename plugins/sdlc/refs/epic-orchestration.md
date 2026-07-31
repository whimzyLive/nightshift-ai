# Epic orchestration — drive every child story

<!-- notation: `:=` define, `->` leads-to, `⊆` drawn-from-set, ASSERT/ELSE guard, first-match-wins ordering. Full legend: refs/pseudocode-notation.md -->

Loaded from `commands/auto.md` **Step 0** — read this file (explicit path:
`${CLAUDE_PLUGIN_ROOT}/refs/epic-orchestration.md`) **only** when `ITYPE=epic`. The single-story
path never loads it. Entered from **Step 0** when `STORY_KEY` is an **Epic**. The epic session
drives every child story to completion in dependency order, spawning **one child `claude` session
per story** and running exactly **one child live at a time**. Throughout this section `EPIC_KEY` =
the epic key passed as `STORY_KEY`.

The epic session keeps its **own** `SDLC_SESSION_KEY=EPIC_KEY`. Each child it spawns gets
`SDLC_SESSION_KEY=<that child's story key>` — the epic key and every child key are distinct, so the
parent's release sentinel and each child's completion sentinel never collide.

## E0 — Epic precondition: the Epic's AI Workflow mode (`epicFallback`)

Read the **Epic's own** AI Workflow mode **once**, at loop start, using
`resolve-ai-workflow-mode.sh` (the same shared implementation the single-story flow uses — see
_Resolving the working issue's mode_) applied to `EPIC_KEY`:

```bash
eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-ai-workflow-mode.sh EPIC_KEY)"
epicFallback="$MODE"   # 'Full Auto' | 'Auto' | 'Assisted' | '' (neither field nor label set, or unreadable)
```

`epicFallback` must be a **real mode string** or empty — never a placeholder — because later
sections interpolate `effectiveMode(S)` into operator-facing prompts.

`epicFallback = "" -> REJECT`: no field value and no fallback label. Post a comment on the **Epic**
explaining that an AI Workflow mode must be set before automation, and exit **without spawning any
session**:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
acli jira workitem comment create --key EPIC_KEY --body "Cannot start epic automation: no AI Workflow mode is set on this Epic.

Set the Epic's AI Workflow field to one of Full Auto / Auto / Assisted — or, on a project without the custom field, add an AI-Workflow:full-auto / AI-Workflow:auto / AI-Workflow:assisted label. It becomes the default mode for every child story that does not set its own. Then re-run /auto EPIC_KEY."
```

Then run the direct `session-complete.sh` release (see **Final action** in `commands/auto.md`) and
exit. # rationale: an unreadable probe is treated as unset — the safe default is to refuse to spawn
anything rather than guess a mode.

## E1 — Build the dependency-ordered queue

Run the queue builder as **one** statically-analysable invocation (all `acli`/`jq`/loops live inside
the script, mirroring `dep-gate.sh`):

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/epic-queue.sh EPIC_KEY
```

Parse its greppable output:

- `ORDER=<k1 k2 …>` := the stories in execution order — a story appears only after every sibling
  that `Blocks` it (the feature-spec dependencies, encoded in the Jira `Blocks` graph).
  Independent stories are tie-broken by Jira `created ASC`.
- one `<key> BLOCKERS=<…>` line per story (informational).
- `GATE=PASS` (exit 0) -> proceed with `ORDER`.
- `GATE=STOP` (exit 1) -> the builder hit an acli failure **or a dependency cycle** (its `REASON=`
  line names the cycle keys). Do not spawn anything — surface the `REASON` to the user, run the
  direct `session-complete.sh` release, and exit.

## E2 — Per-story loop

For each story `S` in `ORDER`, in order, run the steps below. Maintain a `cursor` (see E5) so the
epic is resumable. Exactly **one** child session is live at any moment.

**E2a — Idempotent skip (re-run safety).** Before spawning, probe `S`'s Jira status definitively
(format-stable field read — `acli jira workitem view S --fields status --json` then read
`.fields.status.name`; do not scrape rendered text).
`status(S) == <Pipeline done status> -> skip S without spawning a session`, advance to the next
story. (`<Pipeline done status>` — the consuming repo's terminal status, read from
`.claude/project/project-context.md`'s `## Pipeline` section; the same token the Full-Auto
auto-merge-then-transition hook resolves `<DONE_STATUS>` from. No new terminal status is
introduced here.) This makes re-running `/auto EPIC_KEY` idempotent: already-finished stories are
passed over.

**E2b — Decide whether `S` is gated.** Resolve `S`'s effective mode:

```text
storyMode(S)      := S's own AI Workflow value via resolve-ai-workflow-mode.sh S (Full Auto / non-Full-Auto / unset)
effectiveMode(S)  := storyMode(S) if set, ELSE epicFallback
gated(S)          := effectiveMode(S) != "Full Auto"
```

`Full Auto` is the **only** non-gated value. `Auto`, `Assisted`, and any unreadable mode probe ->
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

## E3 — Gate handling (suspend primitive)

After a child completes (sentinel seen): `gated(S) -> suspend before starting the next story` — the
gated story's PR needs human review + merge first. Suspension goes through a single documented seam
(see **E5 — Suspend-primitive protocol**), and `resolveImpl()` picks the path: the **worker
alternate** emits the `<<<SDLC_EPIC_GATED:…>>>` marker and yields to the worker host (E5a/E5b), the
**interactive default** (implemented here, unchanged) is:

The child has **already** posted its own mode-aware Jira gate comment with the PR link (existing
single-story behaviour — unchanged; the epic adds **no** new Jira comment format). The parent epic
session then **blocks and prompts on stdout**:

```
Story S is gated (mode=<effectiveMode(S)>). PR: <url>. Review + merge, then type 'continue' to proceed to <nextStory>, or 'abort' to stop the epic.
```

- operator input `continue` -> resume **in-process** at the next story (advance the cursor, loop
  back to E2 for `nextStory`).
- operator input `abort` -> **clean stop**: no failure is recorded, the epic simply ends here. Run
  the direct `session-complete.sh` release and exit. (Re-running `/auto EPIC_KEY` later resumes —
  E2a skips every already-done story and picks up where the abort left off.)

`gated(S) == false` (`effectiveMode(S) == "Full Auto"`) -> the child already drove its PR to
auto-merge via its own tail loop — **no suspend**, advance straight to the next story. The
all-Full-Auto epic is therefore **emergent**: no story is ever gated, so the suspend primitive is
never invoked, so the whole epic runs to completion in this single epic session, hands-free.

## E4 — HALT on child failure

A child **succeeds** iff it emits its `<<<SDLC_SESSION_COMPLETE:S…>>>` sentinel.
`child exits non-zero, errors out, or hits its idle timeout with no sentinel -> treat as failure,
HALT the whole epic immediately` — do **not** skip the story and do **not** continue to the next
one:

1. Post a Jira comment on the **failed story `S`** noting the epic run halted on it and why (e.g.
   `child session for S failed: <reason>` — non-zero exit / error / idle-timeout-no-sentinel).
2. Surface an **epic-level halt on stdout** naming the failed story and the reason.
3. Run the direct `session-complete.sh` release and exit.

The epic stays **resumable**: a later `/auto EPIC_KEY` skips every terminal story (E2a) and resumes
at the still-unfinished failed story. An idle-timeout-with-no-sentinel is **always** a HALT, never a
silent skip — a child that went quiet without signalling completion has _not_ succeeded.

## E5 — Suspend-primitive protocol (the seam)

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

### E5a — The two suspend paths

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

### E5b — Epic-gated marker contract (worker-alternate path only)

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
