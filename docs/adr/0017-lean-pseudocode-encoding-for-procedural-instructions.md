---
status: accepted
agents: [ai-enablement-engineer]
source-stories: [NA-86]
---

# 0017. Lean pseudocode encoding for procedural instructions

## Status

Accepted.

## Decision

We will re-encode the **procedural** sections of the SDLC plugin's largest instruction files —
decision tables, guard conditions, and branch chains — in a compact, five-symbol pseudocode
notation, instead of full English sentences, wherever doing so does not change the file's own step
count, step order, or step outcomes.

The notation is five symbols, canonical in `plugins/sdlc/refs/pseudocode-notation.md` (never
auto-loaded) and named inline via a one-time, ≤200-character header comment in every converted
file:

| Symbol            | Meaning                                                               |
| ----------------- | --------------------------------------------------------------------- |
| `:=`              | Assignment / definition                                               |
| `->`              | Leads to / produces                                                   |
| `⊆`               | "Is a member of" / "drawn from" a fixed set                           |
| `ASSERT` / `ELSE` | A guard: what must hold, and what happens on failure                  |
| first-match-wins  | An ordered condition list; evaluate top to bottom, take the first hit |

Mandatory conversion rules:

| Rule                                                                                                                     | Binding  |
| ------------------------------------------------------------------------------------------------------------------------ | -------- |
| Preserve **exactly**: fenced code, inline code, URLs, file paths, commands, exact contract strings                       | MUST     |
| Rationale survives as `#` comments positioned next to the rule it justifies                                              | MUST     |
| Ship the one-time notation legend + inline header line (≤200 chars)                                                      | MUST     |
| Never use a ` ```bash ` fence for pseudocode — use a plain or ` ```text ` fence                                          | MUST     |
| Do **not** convert declarative sections: Why, Role, Inputs, Modes                                                        | MUST NOT |
| Do **not** convert judgment steps: task-derivation steps, verbatim prompt-contract payload items, agent role definitions | MUST NOT |

**The ` ```bash ` exclusion is deliberate, not stylistic:** a pseudocode block is never meant to
execute, and an agent (or a human running commands from the file) could otherwise copy-paste it
into a shell. A plain or ` ```text ` fence makes that category error visibly impossible.

**The AC-7 branch-inventory gate is the mechanism that makes this encoding safe.**
`tools/sdlc-analyser/branch-inventory.sh <file> --base <ref>` counts every file's distinct decision
outcomes (one per `if`/`elif`/`else`/`case` arm, `ASSERT`/`ELSE` pair, decision-table row, or
explicit failure/`STOP`/`blocked` path) before and after a conversion. `OUTCOMES_MATCH=false` blocks
the PR — pseudocode's failure mode is the silent loss of an `else`/failure branch during
compression, and this is the only gate that catches it. Two expected, non-failure mismatch shapes
are documented as reconciliation patterns rather than blockers:

- **Deliberate relocation** — content moved to a sibling ref file or a new script (which the tool,
  reading only `.md` files, cannot see) is reconciled by summing the same outcome-class metric
  across every destination and confirming an exact match on at least one high-signal subclass (see
  the project rule `branch-inventory-mismatch-expected-on-deliberate-relocation`).
- **Keyword false-positives** — the tool's counting rule is a simple, case-sensitive line-pattern
  match (e.g. any line containing lowercase `blocked`), not a semantic parse. A narrative sentence
  that happens to mention an outcome already operatively encoded elsewhere in the file (e.g. a
  "Why inline" aside re-describing a Step-0 guard's own STOP/blocked path) can move the count by
  one without any real branch being added or lost. The manual reconciliation — confirming the
  operative guard is unchanged at its point of use — is authoritative over the raw count, per the
  escalation rule in `tools/sdlc-analyser/README.md`.

## Context

The programme's instruction-load gate (Epic NA-76) measures an 8-point story's total resident
instruction tokens against a ≤230,000-token target. A large share of the SDLC plugin's own
instruction files — `commands/loop.md`, `commands/auto.md`,
`refs/principal-engineer-playbook.md`, `agents/scrum-master.md`, `refs/qa-engineer-playbook.md` —
describe branching, multi-step procedures in full prose: "If X, do Y. Otherwise, if Z, do W." This
is easy to author and easy to read once, but it is also verbose relative to its actual information
content, and every token of it is paid again on every dispatch that loads the file.

At the same time, NA-86's own Global Constraint is absolute: **no behavioural change.** No step
added, removed, reordered, or given a different outcome. Any token-shrinking encoding change had to
come with a mechanical way to prove it did not also silently drop a branch — prose compression is
exactly the kind of edit a reviewer can plausibly wave through without noticing a dropped `else`.

## Alternatives Considered

### Leave the procedural sections as full prose

- Pros: no new notation to learn; zero conversion risk.
- Cons: leaves the largest, highest-frequency-loaded files at their full verbose token cost
  indefinitely; does nothing to close the instruction-load gap A5–A9 target.

### A general-purpose pseudocode/DSL (e.g. a small formal grammar with its own parser)

- Pros: maximally precise; could in principle be machine-validated.
- Cons: over-engineered for markdown instruction files an LLM reads as prose, not a program it
  executes; introduces a new thing to maintain and teach; the story's own scope is encoding and
  packaging, not building tooling nobody but this repo would use.

### Five-symbol lean notation + a ≤200-char inline header + the AC-7 gate (chosen)

- Pros: cheap to learn (one legend, five symbols); cheap to apply (a reformatting pass, not a
  rewrite); the AC-7 gate turns the story's own "no behavioural change" constraint into a mechanical
  check instead of a reviewer's unaided eyeball; a legend nobody has to load (never auto-loaded,
  named inline) costs nothing on the common path.
- Cons: still requires a manual reconciliation step whenever the gate reports a mismatch — relocated
  content and the tool's own keyword-matching false positives both require a human (or agent) to
  write down why a mismatch is safe, rather than a purely mechanical pass/fail.

## Consequences

- `commands/loop.md`, `commands/auto.md`, `refs/loop-modes.md`, `refs/epic-orchestration.md`,
  `agents/scrum-master.md`, `refs/principal-engineer-playbook.md`, and
  `refs/qa-engineer-playbook.md` each carry the one-time inline header naming the five symbols, and
  a canonical legend lives at `plugins/sdlc/refs/pseudocode-notation.md`.
- Every AC2/A3 conversion in this story is backed by an AC-7 `branch-inventory.sh` before/after
  pasted into the PR body — an exact match, or a written manual reconciliation for an expected
  relocation/false-positive mismatch. A future conversion elsewhere in this plugin should follow the
  same discipline: run the gate, and if it disagrees, write down why before treating the mismatch as
  safe.
- The conversion is intentionally uneven across files: declarative sections and judgment-heavy
  content were left as prose by design (see the MUST-NOT rules above), so a reader should not expect
  every branch statement in a converted file to use the notation — only the ones that were already
  full prose describing a genuine decision point.
- `branch-inventory.sh`'s counting rule is a simple, documented heuristic, not a semantic parser —
  it will keyword-match phrases like `blocked` in ordinary narrative prose. This is a known,
  accepted limitation (see the false-positive reconciliation pattern above); tightening the regex to
  reduce false positives is future work, out of scope for this story.
