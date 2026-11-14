# Background story runs

Operating guide for running several stories at once, each as its own background Claude Code session,
and for watching them. Loaded by `commands/run.md`. The launcher is `scripts/run-bg.sh`, the probe is
`scripts/bg-status.sh`. Neither calls an LLM. A single epic session (`refs/epic-orchestration.md`)
runs its stories one after another; this guide is for independent runs side by side.

## One session per story

- Every story gets its own `claude --bg` session named after the story key, started by
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-bg.sh KEY ["note"] [session-id]`.
- Start each in its own background shell call (`run_in_background`), about 30 seconds apart, so each
  start is tracked separately and the repo is not hit by several worktree setups at once.
- The launcher runs from the repo root, sources the optional `.claude/project/bg-run.env`, unsets
  `ANTHROPIC_API_KEY` (subscription billing) and appends the run rules below to the session.
- Attach: `claude attach KEY`. Recent output: `claude logs KEY`. Stop: `claude stop <session-id>`.

### `.claude/project/bg-run.env`

Optional shell file the launcher sources. Everything in it is exported to the session.

| Variable                  | Default       | Use                                                               |
| ------------------------- | ------------- | ----------------------------------------------------------------- |
| `BG_RUN_PERMISSION_MODE`  | `auto`        | `--permission-mode` of the session                                |
| `BG_RUN_COMMAND`          | `/sdlc:auto`  | slash command the session runs for the key                        |
| `BG_RUN_EXTRA_RULES`      | empty         | repo rules appended after the rules below                         |
| any other variable        | unset         | exported to the session, for example the base ref a gate compares |

Repo-specific rules (a test flag, a database URL, a gate base) belong here, never in the plugin.

## Run rules (appended to every session)

1. Dispatch every agent in the foreground and wait for it. Never end a turn while an agent runs.
2. A fresh agent for each fix round and each re-review. Never resume an agent with `SendMessage`.
3. Never grow an allowance list, skip a check or silence a gate to get a pass. Report the failure.
4. Work only in your own worktree. Never touch the uncommitted files of the primary checkout.
5. Human handoff (below).
6. Never call `AskUserQuestion`. Nobody is watching the terminal and it blocks the session. Do the
   human handoff instead, with each question, its options and a recommendation.

## Human handoff convention

When a run stops because a person must decide (a spec to approve, a failing gate it may not
waive, a product question), it must:

1. open the PR as a draft,
2. put a section headed `Needs a human` in the PR body, one bullet per decision,
3. comment the same list on the Jira story,
4. start its last message with `NEEDS YOU:` followed by the decisions.

`bg-status.sh` reads signals 2 and 4, so the monitor can tell a stopped run from a working one.

A run that asks through `AskUserQuestion` anyway sits blocked on a menu nobody sees. `bg-status.sh`
reports it as `NEEDS_HUMAN reason=question` and prints the question ("Answering a run blocked on a
question" below).

## Concurrency

This is guidance, not a hard limit. A repo can set `Max parallel runs` (an integer token in
`.claude/project/project-context.md`, under `## Pipeline`) to change the start value.

- Start with 2 runs. Before adding a third and each one after, check `uptime` and the number of
  database connections (when the repo's tests use a database). Add one run at a time.
- Hard stop at a 1-minute load average of 20: start nothing new until it drops.
- Count a run as live while its verdict is `RUNNING` or `STALLED`. `NEEDS_HUMAN` and `DONE` runs do not
  hold a slot.

## Ordering

- Launch a story only when every story that blocks it is Done (the `Pipeline done status` of
  project-context; `scripts/dep-gate.sh KEY` prints `BLOCKERS=`). A story with open blockers waits.
- A blocker on the gate's `DESIGN_BLOCKERS=` line is the Epic's Design story
  (`refs/design-workflow.md` "The design story"). No run closes it: the story waits with the reason
  `blocked by the Design story <key>` until a person runs `/sdlc:design <EPIC> --final`, merges the
  design PR and moves it to Done. The Design story itself is never launched.
- Stories that touch the same files run one after the other, even when Jira links no dependency.
  If unsure, launch the second one only after the first has a PR.

## Reading a status line

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/bg-status.sh KEY...` prints one line per story:

```
KEY verdict=RUNNING reason=active session=<id> state=busy idle_min=2 jira=In_Progress pr=#12:OPEN:draft checks=none needs_you=no needs_heading=no
```

| Verdict       | Meaning                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------- |
| `RUNNING`     | transcript written within 25 minutes and nothing says it stopped                                  |
| `NEEDS_HUMAN` | `NEEDS YOU:` last message, a `Needs a human` PR heading, a session blocked on a question, or a quiet run with a draft or ready PR |
| `STALLED`     | `blocked` or `waiting` with no pending question, or no transcript write for 25 minutes            |
| `DONE`        | Jira status is the done status, or the PR is merged                                               |
| `NO_SESSION`  | no session named after the key and no PR                                                          |

Two lessons are built in:

- The session `state` is not proof of work. A run can end its turn with a draft PR while the state
  still reads `working` and Jira stays To Do. The transcript age and the PR decide.
- An open PR is not "waiting for checks". `checks=` is the real rollup: `none` (the repo has no CI),
  `pending`, `failing` or `passing`. Only `pending` keeps a run `RUNNING`.

A session blocked on a question adds one last field, `question=`, with the header and text of the
first question on one line (cut at `QUESTION_MAX`, 200 characters). Its value has spaces and runs to
the end of the line:

```
KEY verdict=NEEDS_HUMAN reason=question session=<id> state=waiting idle_min=5 ... question=Reuse: new sibling or generalise the existing one? (+1 more)
```

The probe finds the transcript under the session's own `cwd` from `claude agents --json` (a story
run works in its worktree, so not under the repo root's project folder) and, when that folder has no
file for the session, in any project folder that holds `<session-id>.jsonl`.

Thresholds are `STALL_MIN` (25) and `QUIET_MIN` (3, how long a run is silent before an open PR counts
as a handoff). Set them in the environment to change them.

## Resuming a stalled run

1. `claude stop <session-id>` (the full id from the status line).
2. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-bg.sh KEY "<what to do next>" <session-id>`.

The resumed session keeps its conversation and gets the note as its next prompt. After a human
decision, resume the same way with the answer as the note.

A third argument that is empty, or not a full 8-4-4-4-12 hex session id, is refused and nothing is
launched, so a failed id lookup can never start a fresh run. Expand a short id (like `39d88595`) to the
full `sessionId` from `claude agents --json`.

## Answering a run blocked on a question

A session with `reason=question` cannot be answered from outside: the menu belongs to its terminal.

1. The foreground session asks the person the question from the status line (`claude attach KEY`
   shows every question and its options).
2. `claude stop <session-id>`.
3. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-bg.sh KEY "<answers>" <FULL session id>`.

## Monitor tick

A session-local recurring wakeup that watches the runs and notifies. Create it with `CronCreate` right
after launching, every 10 minutes at an off-minute, with `recurring: true`:

- cron: `4-59/10 * * * *`
- It lives only in this session and expires after 7 days. After a restart, re-arm it (`/sdlc:run`
  with the same keys re-arms without relaunching a story that already has a session).

Prompt template (fill `<KEYS>` and `<WAITING>`; `<WAITING>` is each not-yet-launched story with its blockers):

```
Monitor tick for background runs: <KEYS>.
1. Run: bash ${CLAUDE_PLUGIN_ROOT}/scripts/bg-status.sh <KEYS>
2. For each story compare its verdict with the one you notified last (keep a note in this session).
   On a change to NEEDS_HUMAN, STALLED or DONE, or when its PR becomes merged, send ONE PushNotification
   for that story naming the key, the verdict, the reason and the PR, plus the question= text when the
   reason is question. Never notify twice for the same state.
3. Launch each waiting story whose blockers are now Done (<WAITING>), staggered 30 seconds apart,
   never one still blocked by the Design story,
   within the concurrency guidance of refs/bg-runs.md, with run-bg.sh in its own background shell.
4. When every tracked story is DONE, send one final PushNotification and delete this cron job (CronDelete).
Do not ask questions, resume, stop or fix anything here. This tick only notifies and launches.
```

The tick only notifies. The decision questions are asked by the foreground session: when a push says
`NEEDS_HUMAN`, open the PR body's `Needs a human` list (or `claude attach KEY`), ask the person, then
resume the run with the answer. When the reason is `question`, the push carries the `question=` text.
