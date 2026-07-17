---
name: writing-docs
description: Use when writing, restructuring, or reviewing any prose documentation — a tutorial, how-to guide, reference page, or explanation/conceptual doc — for a public docs site (e.g. Mintlify MDX, docs/, README material), a getting-started guide, an API/CLI reference page, or a "why we built it this way" conceptual page. Applies the Diátaxis framework (see https://diataxis.fr/) — every document belongs to exactly one of the four quadrants (tutorial / how-to guide / reference / explanation), and mixing quadrants inside one document is the single most common documentation failure. Covers the four-quadrant compass for picking the right form, per-quadrant structure templates, an anti-pattern list for quadrant drift, and generic voice/craft rules — repo-specific voice and target output format (e.g. Mintlify MDX) are resolved from the repo's docs-manifest (falling back to project-context), never hardcoded here.
---

# writing-docs — Diátaxis documentation authoring

**Core principle:** a documentation page serves exactly ONE of four distinct reader needs —
learning, doing, looking something up, or understanding — and trying to serve two at once makes
it worse at both. If you find a document explaining theory in the middle of a set of steps, or a
reference page arguing for why a default was chosen, that's not richness, that's quadrant drift,
and the fix is to split it, not to smooth it over.

**Announce at start:** "I'm using the writing-docs skill to author/review this doc."

## Canonical source

This skill distills [Diátaxis](https://diataxis.fr/) (Daniele Procida) — read the live site for
the full treatment; the four-quadrant model, the compass, and the per-quadrant principles below
are drawn from it directly, not invented here. When in doubt about an edge case this skill
doesn't cover, the canonical source is the tiebreaker.

## When to Use

- Whenever you're about to write or substantially restructure a prose documentation page —
  a tutorial, a how-to guide, a reference page, or an explanation/conceptual page — for a public
  docs site or any repo documentation meant to be read (not a code comment, not an ADR — ADRs
  have their own `writing-adrs` skill and their own format for a different purpose: a permanent
  decision log, not reader-facing product/project documentation).
- When the sdlc docs pipeline (`/sdlc:docs` command + `knowledge-engineer` agent) generates or
  updates a doc page — in a repo where that pipeline is adopted.
- When reviewing an existing doc and something feels "off" — the compass below is exactly the
  tool for diagnosing which quadrant a page has drifted out of.

## Why Diátaxis

Diátaxis starts from an observation: documentation readers don't have one kind of need, they have
four, and each is genuinely different in what it demands of the writing:

- Someone **learning** a system wants a safe, guided experience with visible results at every
  step — they need a **tutorial**.
- Someone already competent, trying to **get something done**, wants directions to a specific
  goal — they need a **how-to guide**.
- Someone **working** who needs a fact — a parameter's type, a flag's behaviour, a field's
  default — wants to look it up fast and trust it completely — they need **reference**.
- Someone trying to **understand** why something is the way it is wants context, discussion, and
  connections drawn — they need **explanation**.

These four needs pull writing in different, often incompatible, directions — a page that's trying
to teach AND to be quickly-scannable AND to argue for a design choice is failing all three
purposes at once, because good tutorial prose is _slow and narrated_, good reference prose is
_austere and fact-only_, and good explanation prose is _discursive and opinionated_ — you cannot
write in all three registers on the same page and have any of them land well. **One document, one
quadrant, one register.** This is the one-doc-one-quadrant discipline: every page you write should
be identifiable, from its first paragraph, as belonging to exactly one of the four.

## The Four Quadrants

| Quadrant         | Serves           | Oriented toward               | Reader is…                             |
| ---------------- | ---------------- | ----------------------------- | -------------------------------------- |
| **Tutorial**     | Learning (study) | Action + skill acquisition    | A student, guided step by step         |
| **How-to guide** | Doing (work)     | Action + skill application    | A competent practitioner with a goal   |
| **Reference**    | Looking up       | Cognition + skill application | Someone who needs a fact, fast         |
| **Explanation**  | Understanding    | Cognition + skill acquisition | Someone reflecting, away from the task |

### Tutorial

A lesson, not a demo. The author takes full responsibility for the reader's success: every step
must produce a visible, meaningful result, in a fixed, reliable order, with no branching and no
optional choices — a tutorial is not the place to offer options. Ruthlessly minimize explanation
inline (link out to it instead); explanation offered mid-lesson breaks the reader's flow and
teaches the wrong lesson about how to learn. Aim for total reliability: a tutorial that fails
partway destroys the confidence it exists to build.

### How-to guide

A recipe for someone who already knows the basics and wants a specific, real result. Written from
the user's goal, never from the tool's operations ("how to configure X for zero-downtime
deploys," not "how to click the deploy button"). Action only — no teaching, no theory, no
completeness-for-its-own-sake. It's fine, even expected, for a how-to guide to branch, to skip
steps a competent reader doesn't need, and to link out to reference for the full option list
rather than enumerating every flag inline.

### Reference

Description, and only description, of the machinery: an API, a CLI, a config schema, a set of
fields. Austere, neutral, structured to mirror the actual structure of the thing it describes (one
entry per symbol/command/field, consistent shape throughout) — a reader consults it, doesn't read
it front to back. No narrative, no opinion, no "you should," no "we chose this because" — those
belong in explanation or a how-to guide; link to them instead of importing them.

### Explanation

Discussion, at a distance from the task at hand — the only quadrant where opinion, alternatives,
and "why" belong. Explanation is understanding-oriented: it draws connections, gives context and
history, and is honestly allowed to argue a position ("X is better than Y here because …") in a
way none of the other three quadrants may. Where a documented architectural decision already
exists as an ADR, an explanation page should **link to the source ADR(s)** under `docs/adr/`
rather than re-deriving or duplicating the reasoning — the ADR is the durable, single source of
truth for _why_; the explanation page's job is to make that reasoning accessible and readable in
context, not to fork it into a second copy that can drift.

## The Compass — choosing the right quadrant

When it's unclear which quadrant a piece of content belongs to, ask two questions rather than
trusting a first instinct (per Diátaxis's own compass — a genuine decision tool, not a mnemonic):

1. Does this content inform **action** (doing/practical steps) or **cognition** (thinking/facts)?
2. Does it serve **acquisition** (the reader is studying, building a skill) or **application** (the
   reader already has the skill and is using it)?

| Informs…  | Serves…     | → Quadrant   |
| --------- | ----------- | ------------ |
| Action    | Acquisition | Tutorial     |
| Action    | Application | How-to guide |
| Cognition | Application | Reference    |
| Cognition | Acquisition | Explanation  |

Apply the compass at the level of a whole page when deciding where new content belongs, and at
the level of a paragraph or sentence when a page feels like it's drifting — a single sentence of
explanation dropped into the middle of a how-to guide's steps is exactly the kind of drift the
compass catches that a first read-through can miss.

## Anti-Patterns

Every one of these is the same underlying failure — a document doing the job of a different
quadrant — expressed four different ways. Catch these before publishing:

| Anti-pattern                                                                                                                               | Why it fails                                                                                                              | Fix                                                                                                           |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Tutorial drifting into reference** — the lesson pauses to enumerate every option, flag, or edge case at the step where one is first used | Breaks the guided-lesson flow; the learner didn't ask for completeness, they asked to be shown one path                   | Use the one path the tutorial needs; link to the reference page for the full option list                      |
| **How-to guide explaining theory** — steps are interrupted by "this works because…" or a design-rationale digression                       | Distracts from the action the competent reader came to perform; if they wanted why, they'd be reading explanation         | State the action plainly; link out to an explanation page for the "why," don't inline it                      |
| **Reference containing narrative or opinion** — a field's doc says "you should probably set this to…" or defends why a default was chosen  | Undermines the neutrality reference exists to provide — a reader consulting reference wants facts, not a case being made  | Strip to neutral fact ("Default: `false`."); move any judgement or rationale to a how-to guide or explanation |
| **Explanation giving step-by-step instructions** — a conceptual/background page turns into a numbered procedure partway through            | Conflates two registers a reader can't hold at once — reflective reading and procedural following require different modes | Keep explanation discursive; link to the how-to guide or tutorial that has the actual steps                   |

## Per-Quadrant Structure Templates

Use the quadrant's template as a starting skeleton, not a rigid form — omit a section that
genuinely doesn't apply, but don't add sections that belong to a different quadrant.

### Tutorial template

```markdown
---
title: TODO(fill) learning-oriented title, matching the H1 below
description: TODO(fill) one line, used verbatim as the llms.txt description
# related-adrs: repo-root-relative docs/adr/NNNN-*.md paths this page depends on; audit's
# ADR-drift flag reads it. Leave [] unless the page genuinely references an accepted ADR.
related-adrs: []
---

# [Learning-oriented title, e.g. "Getting started with X"]

[One or two sentences: what the reader will build/achieve, stated plainly — not "in this
tutorial you will learn," just what they'll do. Sets expectations before the first step.]

## Prerequisites

[Concrete, minimal — what must already be true/installed before starting.]

## Step 1: [Concrete first action]

[Instruction in the imperative. Show the exact command/action.]

[The expected, visible result — "You should see…" — so the reader can confirm they're on track.]

## Step 2: [Next concrete action]

...

## What you built

[Brief recap of the end state, so the learner sees what they accomplished. Link onward: to a
how-to guide for the next real task, or to reference/explanation for anything glossed over
along the way.]
```

### How-to guide template

```markdown
---
title: TODO(fill) specific, real-world goal, matching the H1 below
description: TODO(fill) one line, used verbatim as the llms.txt description
# source: repo-root-relative globs; changes to these files make /sdlc:docs sync draft a refresh of this page. Omit to opt out.
source:
  - TODO(fill) repo-root-relative glob, e.g. plugins/sdlc/commands/loop.md
# related-adrs: repo-root-relative docs/adr/NNNN-*.md paths this page depends on; audit's
# ADR-drift flag reads it. Leave [] unless the page genuinely references an accepted ADR.
related-adrs: []
---

# How to [specific, real-world goal]

[One sentence naming the problem/goal this guide solves — not what tool it uses.]

## Prerequisites

[What the reader needs already in place/known — assume competence, don't re-teach basics.]

## Steps

1. [Action, in the imperative, addressed to the goal — branch or note alternatives inline only
   where the real-world problem itself branches.]
2. [Next action.]
   ...

[Optional: a troubleshooting/verification note if the real-world task commonly needs one.]

See [reference page] for the full list of options — this guide only covers what's needed to
reach this specific goal.
```

### Reference template

````markdown
---
title: TODO(fill) exact name of the API/CLI/config surface, matching the H1 below
description: TODO(fill) one line, used verbatim as the llms.txt description
# related-adrs: repo-root-relative docs/adr/NNNN-*.md paths this page depends on; audit's
# ADR-drift flag reads it. Leave [] unless the page genuinely references an accepted ADR.
related-adrs: []
---

# [Exact name of the API/CLI/config surface being described]

[One neutral sentence: what this is, no more.]

## [Symbol/command/field name]

**Type/Signature:** [...]
**Default:** [...] (if applicable)

[Neutral, factual description — what it does, not why you'd want it or when you should use it.]

**Example:**

```[language]
[minimal illustrative usage — illustration only, not a tutorial]
```

## [Next symbol/command/field name]

...
````

Keep entries structurally identical to each other (same fields, same order) — consistency is what
makes reference material fast to scan; a reader shouldn't have to re-learn the shape of each
entry.

### Explanation template

```markdown
---
title: TODO(fill) topic, matching the H1 below, e.g. About X or X design
description: TODO(fill) one line, used verbatim as the llms.txt description
# related-adrs: the docs/adr/NNNN-*.md paths this page discusses; audit's ADR-drift flag reads it.
# List the same ADRs the "Related decisions" section links, so the machine key and the prose agree.
related-adrs: []
---

# About [topic] <!-- or: "[Topic] design", "Understanding [topic]" -->

[Open with the "why" question this page answers — explanation exists to answer a real or implied
"can you tell me about…?"]

[Discursive body: context, history, the forces and trade-offs at play, alternatives considered,
and — unlike every other quadrant — reasoned opinion where it's warranted ("X is preferable here
because…"). Draw connections to other parts of the system; this is the one quadrant where doing
so is the whole point.]

## Related decisions

[Where a documented architectural decision underlies this topic, link the source ADR(s) — e.g.
`docs/adr/0007-use-postgresql-as-primary-datastore.md` — rather than restating the ADR's Context/
Alternatives/Consequences here. If no ADR exists for a decision this page discusses, that's fine —
not every explained decision needs a formal ADR — but check `docs/adr/index.md` first if the repo
has one, before writing "why" content that a kept-current ADR might already own. Skip this check
entirely in a repo with no `docs/adr/` directory at all.]
```

## Voice, Craft, and Output Format (parameterized — never hardcode)

This skill is deliberately generic: it says nothing here about what THIS repo's docs should sound
like or what markup they should be written in, because that varies per repo and per doc-site
platform. Resolve those two things at the START of any drafting or review task, from these sources
in order:

1. **`.claude/project/docs-manifest.md`** (if it exists) — the sdlc `/sdlc:docs` pipeline's
   per-repo manifest of voice guidance and target output format (e.g. Mintlify MDX vs. plain
   Markdown vs. another doc-site's flavor, front-matter schema, any repo-specific terminology or
   tone rules). This is the primary source once a repo has adopted the docs pipeline.
2. **`.claude/project/project-context.md`** — fall back here for anything the docs-manifest
   doesn't state (or when no docs-manifest exists yet): detected stack/framework, any existing
   voice conventions documented for other content (e.g. a marketing/brand voice guide the repo
   already maintains), and the base branch / PR conventions for where a doc change should land.
3. **Neither exists or is silent on a point** — default to plain, precise Markdown with no
   platform-specific extensions, and a neutral, direct technical voice (no unexplained jargon,
   no marketing language, active voice, second person for reader-facing instructional prose).
   Don't invent a house style; state plainly what you defaulted to so a human reviewer can correct
   it.

Regardless of which source resolves voice and format, these craft rules apply universally, because
they follow from the quadrant model itself rather than from any one repo's taste:

- **Match register to quadrant** — tutorial prose is warm, narrated, first-person-plural
  ("we'll…"); how-to prose is terse and imperative; reference prose is austere and impersonal;
  explanation prose may be reflective and first-person ("I" or "we" reasoning through a topic) —
  don't let one page's register bleed into another's.
- **Title says what the page is** — a reader (and a search engine) should know which quadrant a
  page belongs to from its title alone: "Getting started with X" reads as a tutorial, "How to
  configure X" as a how-to guide, "X reference" as reference, "About X" / "X design" as
  explanation. A vague title ("X") tells the reader nothing about what kind of page they're
  opening.
- **Link across quadrants instead of importing content across them** — every quadrant will
  legitimately want to point at another (a how-to guide linking to reference for the full flag
  list, a tutorial linking to explanation for the "why," an explanation page linking to the how-to
  guide with the actual steps) — that's healthy Diátaxis practice, not drift. Drift is when the
  _content itself_ (not just a link) crosses the boundary.
- **No TBDs in published docs** — an unfinished doc is worse than no doc; if a fact is genuinely
  unknown, say what's known and flag the gap explicitly rather than leaving a placeholder.
- **No em-dash inside `title:` or `description:` frontmatter** — `/sdlc:docs`'s `llms.txt` regen
  (`docs-pipeline.md` §8) parses each generated entry positionally as
  `title — one-line description — relative link`, splitting on a space, an em-dash, and a space. An
  em-dash inside either field's own value collides with that delimiter and breaks the split. Use a
  comma, colon, or plain hyphen instead when the title/description itself needs a pause.

## Self-Review Checklist (run before publishing/committing)

- [ ] The page is identifiable as exactly one quadrant from its title and opening paragraph
- [ ] The page carries `title` + `description` frontmatter (both filled — no unfilled
      `TODO(fill)` sentinel left), and `related-adrs:` (empty `[]` unless the page genuinely
      references an accepted ADR); if this is a how-to/integration-guide page with `source:`
      present, its glob(s) are real paths, not the scaffold's `TODO(fill)` example
- [ ] Neither `title:` nor `description:` contains an em-dash — it collides with the `llms.txt`
      regen's field delimiter
- [ ] No anti-pattern from the table above is present anywhere in the page
- [ ] The page follows its quadrant's structure template (sections present, none borrowed from
      another quadrant)
- [ ] Cross-quadrant references are links, not inlined/duplicated content
- [ ] If this is an explanation page discussing a decision with an existing ADR, it links to that
      ADR rather than re-deriving its reasoning
- [ ] Voice and output format were resolved from docs-manifest → project-context → stated default,
      in that order — not assumed or hardcoded
- [ ] No TBDs — any genuine open gap is stated plainly, not left as a placeholder

## Applied to a familiar analogy

Diátaxis's own comparison (cooking) transfers cleanly and is worth keeping in mind when a quadrant
call feels ambiguous: a cooking **lesson** teaches you to cook (tutorial); a **recipe** gets you a
specific dish without teaching you anything (how-to guide); the **nutrition label** states facts
with zero narrative (reference); a **book about the history and science of cooking** helps you
understand cooking more deeply without directly helping you cook tonight's dinner (explanation).
None of the four substitutes for another, and mixing them — a recipe that stops to teach knife
skills, or a nutrition label with marketing copy — makes the result worse at its actual job.
