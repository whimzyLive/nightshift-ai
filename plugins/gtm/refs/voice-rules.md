# Voice Rules — Anti-Slop Quality Bar

The gtm plugin's ECC-derived anti-AI-slop quality bar. This is the hard-bans half of the shared
**copy-review gate** — the other half is the marketingskills `copy-editing` skill. Both are applied
together by `/gtm:site` (command step 3) and, once NA-8 lands, by `/gtm:pulse` — "same gate as
pulse." `content-writer` also reads this ref as part of its context contract (before drafting, not
as a self-check substitute for the gate). Adapted from the
[ECC marketing-agent](https://github.com/affaan-m/ECC/blob/main/agents/marketing-agent.md) hard-bans
list.

This file is prose guidance for the gate — **not executable config, no schema**. Nothing here is
parsed programmatically; the `copy-editing` skill and the command step apply it by reading it.

## 1. Hard bans

Concrete, enumerated — not vibes. A copy artifact fails the gate if it contains any of the
following, in any section (headline, body, CTA, meta description, alt text):

- **AI-tell filler phrases** — reject on sight:
  - "in today's fast-paced world"
  - "unlock"
  - "unleash"
  - "elevate"
  - "supercharge"
  - "seamless"
  - "game-changer"
  - "revolutionary"
  - "cutting-edge"
- **Em-dash-as-crutch overuse** — an em dash used as a substitute for real sentence structure,
  repeated across multiple sentences in the same section. (An occasional, deliberate em dash is
  fine; a pattern of them standing in for periods or commas throughout a section is not.)
- **Hedging** — words that soften a claim without adding information:
  - "arguably"
  - "perhaps"
- **Empty superlatives without proof** — "the best", "the fastest", "the most powerful" with no
  supporting number, comparison, or citation attached. A superlative is allowed only when the copy
  deck carries the fact that backs it (see Positioning discipline below).
- **Title-case marketing-speak headers** — headers written like "Unlock Your Full Potential Today"
  (every word capitalized, generic aspirational phrasing). Section headers should read like normal
  sentences or plain noun phrases, not a conference-banner title case.

This list is a floor, not a ceiling — the `copy-editing` skill may flag additional AI-tell patterns
it detects. The hard bans above are the constructs every gate run must check regardless of skill
version.

## 2. Positioning discipline

Every claim, metric, and quote in the copy deck must trace back to `.agents/product-marketing.md`
(the canonical, founder-owned product-marketing context document). Concretely:

- No invented claims — don't assert something about the product that isn't in the product-marketing
  doc or directly derivable from it.
- No invented metrics — don't fabricate a number ("used by 10,000 teams", "99.9% uptime") that
  isn't sourced from the product-marketing doc or another verified project artifact.
- No invented customer quotes or testimonials — a quote attributed to a customer must be a real
  quote the founder supplied; the gate treats any quote not traceable to a source as a violation.

If the copy deck needs a claim the product-marketing doc doesn't support, the correct move is to
flag it as an open question for the founder (surfaced in `/gtm:site`'s final report), not to
invent supporting material.

## 3. Voice layering rule

The hard bans and positioning discipline above are the plugin's **defaults**. A project may extend
or override them via the **Voice** section of its own `.claude/project/marketing-context.md`.

Merge precedence, stated explicitly so `/gtm:site` and the `copy-editing` skill apply it
identically:

- **Project overrides win on direct conflict.** If a project's Voice section explicitly permits a
  construct this ref bans (or bans something this ref allows), the project's rule governs for that
  project.
- **Un-overridden plugin bans stay in force.** Anything this ref bans that the project's Voice
  section is silent on remains banned — a project Voice section is additive/override, not a full
  replacement of these defaults.
- **The gate enforces the merged result** — not the plugin defaults alone, and not the project
  overrides alone. Read both files before evaluating a copy artifact: this ref, then the project's
  `marketing-context.md` Voice section (when present), and apply the union with project rules
  taking precedence on conflicts.

## 4. Gate outcome contract

The gate produces exactly one of two outcomes. The **dispatching command** (today `/gtm:site`;
`/gtm:pulse` at NA-8) applies the gate and owns the verdict — the marketingskills `copy-editing`
skill is loaded as **review criteria only**, never as an editor: the gate must not rewrite,
revise, or "improve" the artifact (no-automatic-revision is a product-owner decision). Verdict,
not edit:

- **PASS** — no hard-ban violations, no positioning-discipline violations, and the merged (plugin +
  project) rule set is satisfied throughout the copy artifact. The artifact may proceed to brand
  tokens and handoff.
- **FAIL** — one or more violations found. A FAIL:
  - **lists each violation with its offending span** — the exact banned phrase, hedge word,
    unsupported superlative, invented claim/metric/quote, or title-case header text, and which
    section of the copy deck it appears in;
  - **blocks the dispatching command's handoff** — nothing is persisted or routed downstream on a
    FAIL, and at the gate's primary (pre-brand) position nothing is branded either (a re-gate of an
    already-branded merged artifact still blocks persistence and routing). For `/gtm:site`: no
    `docs/gtm/site-brief.md` write, no web-engineer dispatch; future consumers like `/gtm:pulse`
    block their own publish/queue step the same way.
    There is no automatic revision loop; the founder (or a re-run of the dispatching command) must
    address the violations.

A gate run that produces neither a clean PASS nor a FAIL with itemized violations is not a valid
gate run — always report which outcome occurred and, on FAIL, the complete violation list.
