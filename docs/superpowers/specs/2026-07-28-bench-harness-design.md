# Benchmark harness (`plugins/bench`) — design

**Date:** 2026-07-28
**Related:** NA-80 (benchmark experiment), Epic NA-76 (SDLC token and cost optimisation programme)
**Status:** design approved, unimplemented

## Problem

NA-80 asks for a defensible, measured comparison of cost **and** quality for delivering the same
story through four approaches: the SDLC plugin, superpowers skills alone, GitHub spec-kit, and
direct implementation with Opus and no framework. Today only the SDLC column is measured; the
superpowers column is a proxy drawn from scope-matched ad-hoc sessions, the direct-Opus column is a
floor rather than a measurement, and spec-kit has no cost data at all.

The measurement work that answers NA-80 is not a one-off script. It must be re-runnable against any
ticket, in any repository, on any Jira site, so the comparison can be repeated as the SDLC plugin
changes and as new approaches appear. This document specifies that harness.

Scope note: this design covers the harness. Running the 12-cell experiment and publishing the
comparison table remains NA-80's scope and consumes this tool.

## Goals

- A ticket key in, a measured cost-and-quality table out.
- Portable across repositories, Jira projects, and Jira sites.
- Cost attributed **by phase**, never reported as a single per-run total.
- Quality graded blind, with blinding enforced structurally rather than by convention.
- New approaches addable without a code change.
- Zero side effects on real projects and repositories.

## Non-goals

- Not a decision to replace the SDLC plugin. The harness produces evidence, not a migration.
- Not a general framework review. Only the approaches an operator supplies, only on cost and
  delivered quality.
- Not a CI gate. Runs are operator-initiated and cost real money.

## Architecture

A Claude Code plugin at `plugins/bench`, versioned by `nx release` alongside `sdlc` and `gtm`.

```
plugins/bench/
  commands/
    run.md               /bench:run <TICKET> [flags]
    report.md            /bench:report <TICKET>
  approaches/
    sdlc.yaml
    superpowers.yaml
    speckit.yaml
    opus.yaml
  scripts/
    resolve.py           ticket -> normalised story (site-agnostic, via acli)
    provision.py         scratch Jira issue + worktree + scratch remote
    execute.py           run adapter hooks, capture session id and transcript path
    measure.py           transcript -> cost, tokens, requests, wall clock, per phase
    grade.py             blind grading over the code-only diff
    report.py            per-run JSON -> aggregate markdown
    pricing.json         pinned per-model token prices
```

Six scripts, one responsibility each, each runnable standalone against files on disk. Two of those
boundaries carry the design's integrity:

- `measure.py` receives a transcript path and an adapter's phase markers. It never learns which
  approach produced the transcript.
- `grade.py` receives a hash-named directory. It never learns which approach produced the diff.

Blinding is therefore a property of the interfaces, not a promise about prompt wording.

### Configuration resolution

Order: CLI flags, then `.claude/project/project-context.md`, then defaults.

| Setting | Source in project-context |
| --- | --- |
| Jira site | `Jira site` |
| Jira project key | `Jira project key` |
| Base branch | `Base branch` |
| Test command | `Typecheck / Test` |
| Package manager | `Package manager` |

One value has no project-context source and no discovery route, so it lives in bench config:

| Setting | Default | Why it cannot be discovered |
| --- | --- | --- |
| `story_points_field` | `customfield_10016` | `acli jira field` exposes create / delete / update / restore but **no list**, and `workitem view --json` returns no `names` map, so there is no acli path from a field name to its ID on an arbitrary site. |

Two further acli constraints the harness must code around, both verified on
`whimzylive.atlassian.net`:

- `workitem search --fields customfield_10016` is rejected with
  `field 'customfield_10016' is not allowed`. Custom fields are only readable through
  `workitem view --fields '*all' --json`, one issue per call. Band labelling therefore fans out
  per-issue rather than using a single search.
- `--json` output is not always pure JSON. Parsers must seek to the first `{` before decoding.

Any repository already initialised by `/sdlc:init` runs with zero additional setup. Repositories
without that file supply the same values as flags.

## Adapter contract

An approach is a declarative YAML file. The runner resolves it, substitutes variables, and executes
hooks. Templating is `{{var}}` substitution over a fixed variable set — no shell evaluation of
template output.

```yaml
id: speckit
label: GitHub spec-kit
setup:                       # once per worktree; NOT inside the measured window
  - uv tool install specify-cli
  - specify init --here --ai claude
run:                         # the measured session
  prompt: |
    Implement {{ticket_key}}: {{ticket_summary}}

    {{ticket_description}}
  flags: ["--permission-mode", "acceptEdits"]
phases:
  - {id: spec,  marker: "/specify"}
  - {id: plan,  marker: "/plan"}
  - {id: impl,  marker: "/implement"}
teardown:
  - git -C {{worktree}} bundle create {{artifacts}}/repo.bundle --all
```

Available variables: `ticket_key`, `ticket_summary`, `ticket_description`, `ticket_acs`,
`worktree`, `artifacts`, `base_branch`, `test_command`.

`setup` is deliberately outside the measured window. Installing a toolchain is a one-time tax paid
per machine, not a per-story cost, and charging it to the first story would misrepresent the
approach.

Adding a fifth approach is dropping a file. No code change, no plugin release.

## Measurement

### Primary source

Each run executes as `claude -p --output-format json`, which returns `total_cost_usd`,
`duration_ms`, `num_turns`, and `session_id`. These are authoritative and require no reconstruction.

### Breakdown

`measure.py` parses the `session_id` transcript under `~/.claude/projects/` for the detail NA-80
requires:

| Metric | Extraction |
| --- | --- |
| fresh / cache-read / cache-write / output tokens | sum `message.usage.*` per assistant entry, priced by `message.model` against `pricing.json` |
| subagent count | distinct `isSidechain: true` chains |
| avg and peak resident context | `input_tokens + cache_read_input_tokens` per request |
| instruction vs work-context split | instruction floor = **minimum** resident context across requests, since system prompt, skills and CLAUDE.md are present in every request; work context = mean resident context minus that floor |
| work done | `git diff --numstat base..HEAD`, plus `Edit` and `Write` `tool_use` counts from the transcript |

### Reconciliation

If the reconstructed cost and `total_cost_usd` disagree by more than 2%, the run is written with a
`reconciliation_failed` flag and excluded from aggregate figures until resolved. A silently wrong
cost is worse than a missing one.

### Phase attribution

Cost is never reported as a single number. Each adapter declares phase markers; `measure.py`
assigns every request to the phase whose marker most recently fired. Adapters declaring no phases
collapse to a single `impl` phase.

```yaml
# approaches/sdlc.yaml
phases:
  - {id: spec,       marker: "/sdlc:spec"}
  - {id: plan,       marker: "/sdlc:plan"}
  - {id: impl,       marker: "/sdlc:impl"}
  - {id: review-fix, marker: "/sdlc:review|/sdlc:review-fix"}
  - {id: docs,       marker: "/sdlc:docs"}
```

The aggregate report compares three rows rather than one:

- **impl-only cost** — the apples-to-apples number across all four approaches.
- **review + fix cost** — what QA discipline costs. Only SDLC pays it today.
- **ceremony cost** — spec, plan, docs. SDLC-only on the full path.

This resolves a fairness problem that a single total cannot. SDLC runs its own review-and-fix loop,
so its rework is visible and billed; the other three approaches have zero rework by construction
because nothing reviews them. Comparing totals would charge SDLC for a discipline the others simply
skip. Naming review + fix as its own line item makes the trade explicit instead of burying it.

## Grading

`grade.py` receives a directory whose name is a content hash. No approach label reaches the grader.

```
cell-a3f19c/
  diff.patch      code-only; strips docs/superpowers/**, docs/features/**,
                  .specify/**, *plan*.md, commit trailers, branch refs
  acs.md          the original acceptance criteria
  tests.txt       baseline test run and post-run test run
```

Three independent headless graders run per cell. Each returns structured JSON:

- per-AC verdict (met / unmet) with a supporting evidence quote from the diff
- findings list, severity-tagged
- regression verdict against the baseline test run

Scalars are reduced by median, booleans by at-least-two-of-three. Grader disagreement is recorded in
the run JSON rather than averaged away — a cell where graders split is a cell whose quality signal is
weak, and the report should say so.

Because no approach reviews its own output except SDLC, the graders also produce a uniform
"findings a first fix round would have to address" count. That number is comparable across all four
approaches in a way that observed rework rounds are not.

## Artifacts

Process artifacts are stripped from the **graded** diff and never from the **output**. A plan
document is real output that an approach produced; it is simply not evidence of code correctness.

```
docs/benchmarks/<TICKET>/<approach>/
  artifacts/         spec.md, plan.md, .specify/**, ADRs, generated docs — verbatim
  diff.patch         full, everything
  diff.code.patch    graded subset (blinded)
  run.json           metrics, per phase
  transcript.jsonl   full session transcript, subagents included
```

The aggregate report includes an artifact inventory: approach, what it produced, byte counts, and
the phase cost that bought it. Any cost premium is therefore always presented next to the concrete
deliverables it purchased.

## Isolation and side effects

Runs execute against the real Jira project and the real repository, so each approach performs its
full genuine behaviour — Jira comments, pull requests, review loops — and measured cost is honest
rather than a suppressed-writes approximation. Fidelity is bought with pollution risk, which the
guardrails below contain rather than eliminate.

Per cell:

1. Fresh `git worktree` created at the base SHA, on branch `bench/<TICKET>/<approach>/<run-id>`.
2. Source ticket cloned into a **scratch issue in the real project**, labelled `bench-run` and
   linked to the source ticket. The scratch key is substituted into the prompt; the source ticket is
   never written to.
3. Adapter `setup`, then the measured `run`, then `teardown`.
4. Repository bundled into `artifacts/`, worktree removed.

### Guardrails

Because runs touch the real repository, the following are hard requirements, not conventions:

- Every branch a run creates is prefixed `bench/`. A run that attempts to push to any ref outside
  that prefix is aborted.
- Pull requests are opened as **drafts**, so branch protection and auto-merge cannot land one.
- A `PreToolUse` deny hook blocks merge verbs for the duration of a run: `gh pr merge`, pushes to
  `develop` or `main`, and force-pushes to non-`bench/` refs.
- The runner itself never invokes a merge command in any code path.

### Cleanup

`/bench:cleanup <TICKET>` is a first-class command, not a manual chore. It closes every draft PR for
the run set, deletes `bench/*` branches local and remote, and deletes the scratch Jira issues found
by JQL on the `bench-run` label plus the source-ticket link. Scratch issues are discoverable by query
rather than by memory precisely so that cleanup cannot silently miss one.

Issue deletion is irreversible. Cleanup lists what it will delete and requires confirmation before
acting.

### Counterbalancing

Run order is counterbalanced from a seed the runner records in the aggregate report, so cache warming
cannot systematically favour whichever approach happens to run last.

## Story source

Story source is a runner parameter, not a design decision.

- Default: the ticket is implemented against current `HEAD`.
- `--from-sha <SHA>`: replay a completed story from its pre-implementation state.

Replay mode carries a contamination risk that the runner must handle explicitly. A worktree created
from a pre-implementation commit still carries the full git object database, so a run can reach the
real solution through `git log --all`. In replay mode the runner therefore provisions from a shallow
clone at the target SHA with remotes stripped, and excludes that story's spec and plan documents and
its Jira comments from the prompt context. Replay results are flagged in the report so a reader knows
which cells carried that risk.

## Rollout

Build the plugin and all six scripts, then run a single cell — direct Opus — end to end, validating
that:

- reconstructed cost agrees with `total_cost_usd` within 2%
- phases attribute correctly
- the graded diff contains no approach-identifying content
- the aggregate report renders from one run

The remaining eleven cells are a separate go / no-go decision once that pilot lands.

## Resolved during design

- **Story points field.** `customfield_10016` on `whimzylive.atlassian.net`, verified against NA-71
  (5 points). Not auto-discoverable — see the configuration section. The full Done-story band map at
  time of writing: 2pt ×1, 3pt ×11, 5pt ×16, 8pt ×14, 13pt ×1, unpointed ×4, so all three bands
  NA-80 requires have candidates.
- **Jira scratch target.** Scratch issues inside the real NA project, labelled `bench-run`, deleted
  by `/bench:cleanup`. Chosen over a cloned BENCH project because workflow, statuses and custom
  fields are then guaranteed to match production exactly, which is what SDLC's transitions depend on.
- **Git scratch target.** The real repository, `bench/*` branches, draft PRs, never merged. Chosen
  for faithful CI behaviour. The guardrails in the isolation section exist to contain the merge risk
  this choice introduces.

## Accepted risks

Both scratch-target decisions trade containment for fidelity. Recorded here so the eventual writeup
does not have to rediscover them:

- Benchmark issues appear on the real NA board while runs are in flight.
- Up to twelve draft PRs and their branches exist on the real repository until cleanup runs.
- Cleanup deletes real Jira issues. It is confirm-gated, but a mis-scoped JQL is the one failure mode
  that could reach beyond the benchmark set.
