---
name: writing-adrs
description: Use when authoring an Architecture Decision Record (ADR) — a short document that captures one significant, hard-to-reverse technical or architectural decision, its context, and its consequences. Triggered by the sdlc ADR pipeline (the knowledge-engineer agent behind /sdlc:docs seed adr and /sdlc:docs distill) when generating an ADR from a story, and by anyone hand-authoring an ADR under docs/adr/ today. Covers why ADRs are kept short and inverted-pyramid, the required sections (Title, Status, Decision, Context, Alternatives Considered, Consequences), the proposed→accepted→superseded (or →rejected) status lifecycle and the never-edit-only-supersede immutability rule, the NNNN-decision-slug.md filename convention, and the ADR frontmatter fields (status, agents, source-stories) the pipeline reads to route a generated ADR into docs/adr/index.md.
---

# writing-adrs — Architecture Decision Records

**Core principle:** an ADR records ONE decision — not a design, not a feature, not a whole
subsystem. If you find yourself wanting to describe several decisions in one file, that's a
signal to split it into several ADRs.

**Announce at start:** "I'm using the writing-adrs skill to author this ADR."

## When to Use

- Whenever a decision is architecturally significant: it affects structure, non-functional
  characteristics (performance, security, cost), external dependencies, interfaces between
  systems, or is expensive to reverse later.
- When the sdlc ADR pipeline (`/sdlc:docs seed adr` / `/sdlc:docs distill` + `knowledge-engineer`
  agent) generates an ADR from a Jira story or a completed piece of work — in a repo where that
  pipeline is adopted.
- Not for routine implementation choices that any competent engineer would make the same way
  and that cost nothing to change later — those don't need a permanent record.

## Why ADRs Look the Way They Do

This isn't an arbitrary template — every rule below exists to solve a specific failure mode.
Understanding the "why" matters more than following the shape mechanically, because a generated
ADR that hits every section heading but skips the reasoning behind them is not actually useful
to the future reader it's written for.

- **One decision per record, not one document per subsystem.** A record that bundles several
  decisions together can't be individually superseded — the moment one part of it changes, the
  whole document is stale, and a reader can no longer trust any of it. Keeping each ADR to a
  single decision means later decisions can supersede exactly the part that changed, leaving the
  rest of the history intact.
- **Short, and inverted-pyramid.** Nobody reads long documents, and documents that aren't read
  don't get kept up to date. Bite-sized, modular records are the ones that actually survive.
  Inverted-pyramid — decision and its consequences up front, supporting detail pushed later —
  means a reader who only has thirty seconds still gets the part that matters; someone who wants
  the full reasoning keeps reading. Aim for a couple of pages, ideally one; link out to
  supporting material rather than inlining it.
- **Context states the forces, in value-neutral language.** An ADR isn't a sales pitch for the
  decision that was made. The Context section should read like a value-neutral description of
  the tensions in play (technical, organizational, timeline, cost) — the same forces a different
  team, in the same situation, would have had to weigh. This is deliberately borrowed from
  pattern-writing's notion of "forces": a pattern doesn't argue that its solution is universally
  correct, it explains what tensions the solution resolves.
- **Alternatives Considered is not optional decoration.** Writing down every serious alternative,
  with honest pros and cons, is what makes the record trustworthy. A record that only justifies
  the chosen option looks like it was written after the fact to rationalize a decision already
  made — and it robs a future reader (including a future you) of the ability to tell whether an
  alternative that's newly attractive today was already considered and rejected, or never
  evaluated at all.
- **Consequences must be explicit, including the negative ones.** Some consequences follow so
  obviously from the decision that it's tempting to leave them implied. Don't — write them down
  anyway. A decision has positive, negative, and neutral consequences, and all of them will
  affect the team later; a record that only lists the upside is a record that's misleading by
  omission. This section is also where you name what would trigger revisiting the decision.
- **Decisions are made under uncertainty — say so.** An ADR that reads as if the outcome were
  obvious in advance misrepresents how the decision actually happened, and teaches future readers
  the wrong lesson about how to make their own hard calls. If confidence was low, or the decision
  hinges on an assumption that might not hold, state that plainly rather than writing with false
  certainty.
- **Accepted records are immutable; supersede, never edit.** The value of an ADR is as a
  historical log — proof of what the team believed and why, at the time. Editing an accepted
  record in place destroys that: a reader (or another agent) with a link to it later has no way
  to know the ground shifted under them. This is exactly how source control itself works, and for
  the same reason — the record of what happened matters as much as the current state. The exact
  rule and how superseding works are stated once, in full, under Status Lifecycle & Immutability
  below — this bullet is a pointer to it, not a second copy.
- **Kept in the source repo, in plain markdown, monotonically numbered.** Storing ADRs alongside
  the code they govern means they travel with the code (checked out, diffed, reviewed the same
  way), and a lightweight markup language keeps them cheap to read and write. Monotonic numbering
  in the filename means a directory listing alone shows the order decisions were made — useful
  even before opening a single file.

## Required Sections

Every ADR — hand-authored or pipeline-generated — MUST contain these sections, in this order:

1. **Title** — a short noun phrase naming the decision, not the problem (e.g. "Use PostgreSQL as
   the primary datastore", not "Datastore options"). The ADR number belongs in the filename, not
   necessarily repeated in the title.
2. **Status** — one of `proposed`, `accepted`, `superseded`, `rejected` (see Status Lifecycle
   below). If superseded, link to the ADR that replaces it. If superseding another ADR, link back
   to the one it replaces.
3. **Decision** — what was decided, stated as a clear, active-voice commitment ("We will …"), not
   a passive description of an option. This is the part inverted-pyramid puts first for a reason:
   lead with the answer.
4. **Context** — the forces and trade-offs that made this decision necessary: technical,
   organizational, timeline, cost, political — whatever actually applied. Value-neutral; describe
   the tensions, don't argue for the outcome yet.
5. **Alternatives Considered** — every serious alternative that was on the table, each with its
   own pros and cons. An alternative dismissed in one sentence with no stated downside wasn't
   seriously considered — say so, or give it a real trade-off.
6. **Consequences** — the full result of making this decision: positive, negative, and neutral.
   Never leave a consequence implied because it "obviously follows" — write it down. Note what
   would trigger the team to revisit the decision.

An ADR MAY also carry an optional **Confidence** note inside Consequences (or its own short
subsection) when the decision was made under real uncertainty — say what assumption it hinges on
and what evidence would change the answer. Omit it when confidence was genuinely high; don't
manufacture doubt that wasn't there.

## Status Lifecycle & Immutability

```
proposed  →  accepted  →  superseded
proposed  →  rejected
```

- `proposed` — under discussion, not yet binding. Safe to edit freely while in this state.
- `accepted` — the team has agreed and the decision is active.
- `rejected` — the proposal was discussed and declined; terminal, it never later becomes
  `accepted`. If the idea resurfaces, write a fresh ADR at a new number rather than reviving a
  rejected one — the number stays retired, same as any other ADR number.
- `superseded` — no longer the operative decision, but preserved so the history of what the team
  believed (and when it changed its mind) stays intact.

**Immutability rule (stated once, here — every other mention in this skill is a pointer back to
this paragraph, not a restatement):** once an ADR reaches `accepted`, never edit its substance.
The only permitted in-place change is a purely cosmetic fix (typo, broken link) that no reader
could interpret as changing the decision, context, alternatives, or consequences; anything else
requires a new superseding ADR instead.

**Supersede flow:** when a decision needs to change, write a brand-new ADR at the next sequence
number and let it follow the normal lifecycle like any other — it starts `proposed`, not
`accepted`. Only at the moment the new ADR is itself accepted do the two records flip together:
the new one becomes `accepted`, and the old one becomes `superseded` — never before, since the old
decision is still the operative one until its replacement is actually accepted, not merely
drafted. Add the cross-links both ways at that same moment (old → "Superseded by ADR-NNNN", new →
"Supersedes ADR-NNNN"). The superseded record stays in the repo permanently — it's a historical
fact, not a mistake to delete.

## Filename & Location Convention

- Directory: `docs/adr/`
- Filename: `NNNN-decision-slug.md` — a four-digit, zero-padded, monotonically increasing number
  (never reused, even for a superseded or rejected ADR) followed by a kebab-case slug of the
  decision itself (not the problem). Example: `0001-htmx-for-active-web-pages.md`.
- Before assigning a new number, list `docs/adr/` and take the highest existing number + 1 — don't
  guess or leave gaps.

## ADR Frontmatter (pipeline routing)

This is distinct from this SKILL.md's own frontmatter above — it's the YAML frontmatter that
belongs at the top of every **generated ADR file** itself, so the sdlc ADR pipeline (the
`knowledge-engineer` agent behind `/sdlc:docs seed adr` / `/sdlc:docs distill`) can route and index
it without re-parsing prose.
Authoring with this frontmatter costs nothing even in a repo that hasn't adopted the pipeline yet,
and needs no retrofitting once it does:

```yaml
---
status: proposed # proposed | accepted | superseded | rejected
agents: [web-engineer, platform-engineer] # which sdlc agents this decision is routed to
source-stories: [PROJ-142, PROJ-156] # Jira keys that motivated or are evidenced by this decision
---
```

- `status` — mirrors the Status section inside the document body; keep both in sync. This is the
  field the pipeline reads to decide whether an ADR is still binding.
- `agents` — the sdlc agent name(s) (matching the agent identifiers used elsewhere in this
  plugin, e.g. `web-engineer`, `platform-engineer`, `database-administrator`) whose future work
  this decision constrains or informs. An ADR can name more than one agent when the decision
  spans domains; name every agent it's genuinely relevant to, not just the one that happened to
  write it.
- `source-stories` — the Jira story key(s) that led to this decision (an evidence trail back to
  why it exists), as a list even when there's only one.

Where the sdlc ADR pipeline is installed and in use — the `knowledge-engineer` agent and its
regeneration tooling, shipped as of sdlc `0.33.0` — a generated `docs/adr/index.md` is rebuilt
deterministically from this frontmatter across every file in `docs/adr/`: grouped into a section
per agent named in `agents`, plus one `General` (unrouted) section for any ADR whose `agents` list
is empty or omitted, so no ADR is ever silently dropped from the index just because it wasn't
routed anywhere. Each listing carries the ADR's number, title, and status. Because the index is
fully derived from frontmatter in a repo that has adopted the pipeline, never hand-edit
`docs/adr/index.md` directly there; fix the frontmatter of the source ADR(s) and regenerate
instead — otherwise the index will just be silently overwritten out of sync on the next
regeneration. In a repo that hasn't adopted the pipeline (or hasn't yet run `/sdlc:docs seed adr` /
`/sdlc:docs distill`), a hand-maintained index (or no index at all) is perfectly fine — the
never-hand-edit rule only starts to apply once there's something to regenerate from.

Hand-authored ADRs that aren't part of the pipeline may omit `agents`/`source-stories` if there's
no sdlc routing use for them yet, but should still carry `status` — it costs nothing and keeps
the file consistent with every other record in the directory.

## Template

```markdown
---
status: proposed
agents: []
source-stories: []
---

# NNNN. [Decision title — a short noun phrase naming what was decided]

## Status

Proposed

## Decision

[The commitment, in active voice: "We will …". Lead with this — inverted pyramid.]

## Context

[The forces at play: technical, organizational, timeline, cost. Value-neutral — describe the
tension, don't argue for the outcome yet.]

## Alternatives Considered

### [Alternative 1 name]

- Pros: [...]
- Cons: [...]

### [Alternative 2 name]

- Pros: [...]
- Cons: [...]

## Consequences

- [Positive consequence]
- [Negative consequence — never omit these]
- [Neutral consequence, if any]
- Revisit this decision if: [the condition that should trigger re-evaluation]
```

## Worked Example

The example below (adr-tools' own ADR set on GitHub, and Harmel-Law's and Rowse/Shepherd's format
variants on martinfowler.com, are further worked examples worth reading) shows the required
sections filled in at the right level of detail — decision first, honest alternatives, explicit
consequences including the negative one:

```markdown
---
status: accepted
agents: [database-administrator, platform-engineer]
source-stories: [PROJ-89]
---

# 0007. Use PostgreSQL as the primary datastore

## Status

Accepted

## Decision

We will use PostgreSQL as the primary datastore for all new services, replacing the
per-service choice that previously let teams pick their own database.

## Context

Each service currently owns its choice of datastore, chosen independently by whichever team
built it first. This has produced four different databases in production, each requiring its
own backup tooling, monitoring, and on-call expertise. New hires need to learn a different
query language and operational model depending on which service they touch first. At the same
time, two of our services have genuinely relational, multi-table transactional workloads that a
key-value store handles awkwardly, while none of our workloads yet require the horizontal write
throughput that would justify a distributed database's added operational cost.

## Alternatives Considered

### Keep per-service choice (status quo)

- Pros: teams retain full autonomy; no migration cost; no risk to services already stable on
  their current datastore.
- Cons: four operational surfaces to maintain indefinitely; onboarding cost compounds with every
  new service; no shared tooling for backups, migrations, or observability.

### Standardize on a distributed/NoSQL store

- Pros: horizontal write scaling available if a future workload needs it; some existing services
  are already comfortable with a document model.
- Cons: none of our current workloads need that scale, so we'd be paying its operational
  complexity cost today for a benefit we don't yet use; relational workloads would need
  significant application-level rework to fit a document model.

### Standardize on PostgreSQL

- Pros: handles our existing relational workloads natively; one operational surface (backups,
  monitoring, migrations, on-call runbooks); mature tooling and hiring pool; a managed offering
  is already in use for one service, so some operational muscle exists.
- Cons: services already comfortable on their current non-relational store face a real migration
  cost; PostgreSQL's horizontal write scaling story is weaker than a distributed store's, which
  matters if a future workload needs it.

## Consequences

- One database technology to operate, monitor, back up, and hire for — the onboarding and
  tooling cost this decision was meant to fix goes away for every service built from here on.
- Existing services on other datastores are not migrated by this decision alone — each needs its
  own migration plan and its own ADR when that work is scheduled, since data migration risk is a
  separate decision from "which store new services use."
- We are accepting a weaker horizontal write-scaling story than a distributed store would give
  us. Confidence here is moderate, not high: none of our current workloads are close to the
  point where this would matter, but if a future workload needs sustained high write throughput,
  that's the specific trigger to revisit this decision rather than defaulting to PostgreSQL by
  habit.
```

## Self-Review Checklist (run before saving)

- [ ] Exactly one decision in this record — not a bundle of several
- [ ] Decision section leads, stated in active voice ("We will …")
- [ ] Context describes forces/trade-offs in value-neutral language, not a justification
- [ ] Every serious alternative is listed, each with real pros AND cons (not one-sided)
- [ ] Consequences are explicit and include negative/neutral ones, not just the upside
- [ ] A revisit trigger is named if the decision was made under real uncertainty
- [ ] Whole document is a couple of pages max — link out rather than inlining supporting material
- [ ] Filename follows `NNNN-decision-slug.md` in `docs/adr/`, number is the next unused one
- [ ] Frontmatter `status` matches the Status section in the body
- [ ] If pipeline-generated: `agents` names every sdlc agent this decision is genuinely relevant
      to; `source-stories` lists the motivating Jira key(s)
- [ ] If this ADR supersedes another: both records cross-link, and the old one's `status` is set
      to `superseded`
- [ ] If this ADR is `accepted`: nothing about the decision, context, alternatives, or
      consequences was edited after acceptance — a substantive change went into a new ADR instead

## Anti-Patterns

| Anti-pattern                                                              | Fix                                                                                                                 |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Editing an `accepted` ADR's Decision/Context/Consequences in place        | Write a new ADR, link both ways, mark the old one `superseded`                                                      |
| Bundling several decisions into one record                                | Split into separate ADRs, one decision each                                                                         |
| Alternatives section that only lists the option that "lost," no pros      | Give every alternative real pros AND cons — a one-sided list reads as rationalization                               |
| Consequences section that only states positives                           | List negative and neutral consequences too — never leave them implied                                               |
| Multi-page document covering a whole subsystem's design                   | Cut to the single decision; link to supporting material instead of inlining it                                      |
| Writing with false certainty about a decision made under real doubt       | State the uncertainty and the revisit trigger honestly                                                              |
| Filename without a monotonic number, or reusing a superseded ADR's number | Always take the highest existing number in `docs/adr/` + 1                                                          |
| Hand-editing a pipeline-generated `docs/adr/index.md` directly            | Fix the source ADR's frontmatter and regenerate instead (fine to hand-maintain the index until the pipeline exists) |
