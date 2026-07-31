# Lean pseudocode notation legend

Canonical, single-source legend for the compact notation used in the **procedural** sections of
`commands/loop.md`, `commands/auto.md`, `refs/loop-modes.md`, and `refs/epic-orchestration.md`
(NA-86 A2/A3). **This file is never auto-loaded** — it exists for a human or agent that lands on
an unfamiliar symbol and wants the full definition; every converted file also carries a one-line
inline header naming the five symbols, so a cold reader never strictly needs to open this file.

| Symbol | Meaning |
| --- | --- |
| `:=` | Assignment / definition — "the left side is defined as the right side's result." |
| `->` | Leads to / produces — a condition or step on the left leads to the outcome on the right. |
| `⊆` | "Is a member of" / "drawn from" a fixed set — used for enum-like value constraints. |
| `ASSERT` / `ELSE` | A guard: `ASSERT <condition>` states what must hold; `ELSE <action>` is what happens on failure — the pseudocode analogue of an `if`/`else` or a shell `[ cond ] || <action>`. |
| first-match-wins | For an ordered list of conditions, evaluate top to bottom and take the **first** one that matches — later conditions are never consulted once one has matched (mirrors a `case`/`elif` chain or a markdown decision table evaluated in row order). |

## What gets converted, what does not

Per the Epic's binding conversion rules (restated here as a pointer, not duplicated in full —
see the story's own Global Constraints for the authoritative list):

- Preserve **exactly**: fenced code, inline code, URLs, file paths, commands, exact contract
  strings. Pseudocode notation never touches these.
- Rationale (the "why") survives as `#` comments positioned next to the rule it justifies, not as
  prose paragraphs threaded through the steps.
- Never wrap pseudocode in a ` ```bash ` fence — something might execute it. Use a plain or
  ` ```text ` fence.
- **Never converted:** declarative sections (Why, Role, Inputs, Modes) and judgment steps (e.g. a
  task-derivation step, or an agent role definition) — these describe *what something is*, not a
  sequence of decisions, and lean notation would make them harder to read, not easier.

## Worked example

```text
review_mode := read_review_config(phase)
ASSERT review_mode ⊆ {none, on-create, on-update} ELSE default to on-update
review_mode = none -> run on-clean hook once, release session   # rationale: no review requested
review_mode != none -> proceed to the decision table            # first-match-wins across its rows
```
