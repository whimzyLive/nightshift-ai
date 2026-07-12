# PRD — nightshift marketing site (design-handoff build)

- **Epic:** NA-29 — "Nightshift marketing site — design-handoff build"
- **Date:** 2026-07-12
- **Author:** Product Manager (SDLC `/prd`)
- **Status:** Draft — ready for Solutions Architect
- **Design source of truth:** `docs/design/marketing-site-handoff/README.md` (+ `designs/`, `tokens/`, `screenshots/`)
- **SEO source of truth:** `docs/gtm/site-brief.md` (meta/OG, JSON-LD, `llms.txt`)

---

## 1. Executive summary

Build the four-page nightshift marketing site — **Home / landing**, **Why SDLC**, **The team**, **FAQ** — as a pixel-perfect recreation of the approved high-fidelity design handoff, inside the existing `apps/marketing` Next.js app. The site exists to drive adoption: get a visitor to copy the two-line install command and star the GitHub repo. Editorial copy (FAQ answers and the editorial "why" paragraphs) is served from the Payload CMS as pre-seeded content; factual/reference content (tooling facts, agent rosters, slash commands, install snippets) stays static in code. Styling is Tailwind v4 CSS-first with the nightshift design tokens and intentional sharp edges.

## 2. Problem statement

nightshift is a free, MIT-licensed Claude Code plugin that runs a full software-delivery lifecycle from a Jira ticket. It has no dedicated marketing presence that (a) explains the SDLC value quickly enough to convert a browsing developer, (b) overcomes the skeptic's "why not just one-shot the AI?" objection, and (c) makes installing frictionless. A prospective adopter today has no single page that turns curiosity into an install and a star. Separately, maintainers have no way to correct or refresh editorial copy (FAQ answers, positioning "why" paragraphs) without a code change and redeploy, which slows the natural iteration a launch page needs.

**Evidence / context:**

- The approved design handoff was produced specifically to solve the adoption-conversion problem — its stated job is "get a visitor to copy the two-line install command and star the repo."
- A prior marketing-site direction (Epic NA-20, 3D/three.js hero) exists but is superseded by this CSS night-sky handoff (see Open Questions for the formal reconciliation decision).
- Copy is already written and approved inside the design files and the gtm site brief — the gap is a shipped, on-brand, high-fidelity site, not new content.

## 3. Target users & personas

Roles are drawn from the Epic's "Target Users" and the project context.

1. **Prospective adopter** — a developer or engineering lead evaluating the plugin. Lands, grasps the SDLC value fast, copies the install command, stars the repo.
2. **Skeptical engineer** — weighing an SDLC pipeline against one-shot AI. Reads _Why SDLC_ and the _FAQ_ to build trust before installing.
3. **Content editor / maintainer** — updates FAQ answers and editorial "why" copy through the Payload CMS without a code deploy.

Surface: **web only** (desktop-first, responsive). No mobile app, no offline mode.

## 4. Strategic context

- Adoption funnel for an open-source plugin: awareness → understanding → trust → install + star. This site owns the understanding → trust → install span.
- The build must not dilute the approved brand experience: fidelity is a first-class requirement, not a nice-to-have. Approved copy is frozen.
- Maintainer velocity: editorial copy needs a no-deploy edit path (CMS); authoritative technical facts need to stay in code so they cannot drift from the actual plugin.

## 5. Solution overview

A four-page site inside `apps/marketing`:

1. **Home / landing** — long-scroll conversion page (10 sections in the handoff order: hero → proof bar → problem → how it works → review-by-day-ship-by-night → the team → why builders choose it → you-decide-how-it-gets-built control section → top-5 FAQ → final CTA), with the animated night-sky chrome, animated terminal, and interactive triage/gate/comparison components.
2. **Why SDLC** — positioning-argument page with a scroll-lit gate rail and a sticky crossfading visual pane, plus a small page FAQ and CTA.
3. **The team** — company-style org chart of the agent roster (departments, profile cards with model-tier badges), a "company handbook" terminal, and an install CTA.
4. **FAQ** — twelve questions in five eyebrow groups as grouped accordions, one answer open at a time, install CTA at the bottom.

Site-wide chrome (all pages): night-sky background, glass nav that detaches into a floating sharp-cornered bar past the hero, glass footer, cursor glow, neon inverted CTA buttons, heading glow, hover-lift cards — all honoring `prefers-reduced-motion`.

**Content split (decided):**

- **CMS-driven (Payload collections/globals, pre-seeded):** FAQ entries (question + answer, grouped) and the editorial "why" paragraphs.
- **Static in code:** tooling facts, agent rosters, slash commands, install snippets, and all structural/layout copy.

**SEO layer:** meta/OG tags, JSON-LD (`SoftwareApplication` + `FAQPage` + `HowTo`, plus per-page `WebPage`/`BreadcrumbList`), and `llms.txt`, all sourced from `docs/gtm/site-brief.md` and wired at build time. FAQ answers rendered on the page must stay text-identical to the `FAQPage` schema.

## 6. Success metrics

- **Primary:** count of install-command copies (both snippets) and GitHub star click-throughs originating from the site.
- **Fidelity:** each page visually matches its handoff reference and screenshots at the key scroll positions (sign-off by side-by-side review).
- **Editability:** a maintainer can change an FAQ answer or a "why" paragraph via the CMS and see it live without a code deploy.
- **Integrity:** rendered FAQ answers are byte-identical to the `FAQPage` JSON-LD; the CMS is never empty on first deploy (seed runs).
- **Accessibility:** all interactive/animated behavior degrades correctly under `prefers-reduced-motion`; text meets the design system's WCAG-AA contrast expectations.

> Instrumentation tooling for the primary metric is an open product decision (see Open Questions) — this PRD scopes _what_ to measure; the _how/which tool_ is TBD.

## 7. User stories & requirements

### User story (primary)

> **As a** prospective adopter evaluating nightshift,
> **I want** a fast, on-brand four-page site that explains the SDLC value and makes installing a one-copy action,
> **so that** I can install the plugin and star the repo without leaving the page to go research it.

### Supporting user stories

1. As a prospective adopter, I want a hero that states the value in one line and shows the install command immediately, so that I can install within 60 seconds of landing.
2. As a prospective adopter, I want a one-click copy on each install snippet, so that I don't have to hand-select terminal text.
3. As a prospective adopter, I want a "Star on GitHub" action in the hero, nav, and final CTA, so that I can star the repo from wherever I am on the page.
4. As a prospective adopter, I want an animated terminal showing a real `/auto` run, so that I can see the pipeline work before I install.
5. As a skeptical engineer, I want a _Why SDLC_ page that argues the case section by section, so that I can decide whether an SDLC pipeline beats one-shot AI.
6. As a skeptical engineer, I want the side-by-side "one-shot AI vs nightshift" comparison, so that I can see the difference in outcomes concretely.
7. As a skeptical engineer, I want a comprehensive FAQ grouped by topic, so that I can resolve my specific objection (workflow, setup, trust, cost/license) quickly.
8. As a visitor, I want the _team_ page to show who does what across the agent org, so that I trust the pipeline is structured, not a single opaque model.
9. As a visitor, I want the night-sky brand experience (starfield, glass nav, cursor glow, neon CTAs) rendered at high fidelity, so that the product feels credible and polished.
10. As a visitor who prefers reduced motion, I want all animations to respect my OS setting, so that the site is comfortable and accessible to me.
11. As a visitor on a smaller screen, I want the pages to remain readable and usable, so that I can evaluate nightshift on any device.
12. As a content editor, I want to edit FAQ answers in the CMS, so that I can correct or improve them without a code deploy.
13. As a content editor, I want to edit the editorial "why" paragraphs in the CMS, so that I can iterate on positioning copy without engineering.
14. As a content editor, I want the CMS to already contain the approved copy on first launch, so that I never see or ship an empty site.
15. As a maintainer, I want tooling facts, agent rosters, commands, and install snippets kept in code, so that they cannot drift from the actual plugin behavior.
16. As a search/AI-discovery stakeholder, I want meta/OG tags, JSON-LD, and `llms.txt` wired in, so that the site is discoverable by search engines and AI assistants.
17. As a search stakeholder, I want the rendered FAQ answers to match the `FAQPage` structured data exactly, so that structured data stays valid and consistent.
18. As a later SDLC phase (spec/plan/impl), I want the design handoff committed in the repo, so that I can reference the authoritative design without the session scratchpad.

### Acceptance criteria (binary, testable)

1. All four pages (Home, Why SDLC, The team, FAQ) exist in `apps/marketing`, are reachable via the nav, and each visually matches its handoff reference/screenshots at the documented key scroll positions.
2. Every install snippet and the GitHub-star actions are present in the locations specified by the handoff (hero, nav, final/section CTAs); each install snippet copies its exact command to the clipboard on click; each star action opens the GitHub repo in a new tab.
3. FAQ entries and the editorial "why" paragraphs render from Payload CMS content (not hard-coded); tooling facts, agent rosters, slash commands, and install snippets render from static code.
4. An idempotent seed populates the CMS with the approved handoff copy; running it against a fresh database yields a fully populated site, and re-running it does not duplicate or corrupt content.
5. Editing an FAQ answer or a "why" paragraph in the CMS changes the live page without a code deploy.
6. Rendered FAQ answer text is identical to the corresponding `FAQPage` JSON-LD answer text.
7. Meta/OG tags, JSON-LD (`SoftwareApplication` + `FAQPage` + `HowTo`, plus per-page `WebPage`/`BreadcrumbList`), and `llms.txt` are present and populated from `docs/gtm/site-brief.md` values.
8. All styling uses Tailwind v4 CSS-first `@theme` with the nightshift design tokens as CSS variables; there are no CSS Modules or SCSS files added for this work; all rectangles render with sharp edges (radius 0) and only intended circles stay round.
9. Every animated/interactive behavior (starfield, meteors, cursor glow, terminal typing, accordions, gate/crossfade, triage/comparison state machines) is disabled or reduced when `prefers-reduced-motion` is set, and no page depends on motion to convey information.
10. No approved design copy is reworded; the page copy matches the design files verbatim.

## 8. User flows

### Happy path — adopter converts

1. Visitor lands on Home hero → reads the one-line value prop and pipeline line.
2. Clicks copy on the first install snippet → command is on the clipboard (visual confirmation).
3. Scrolls, sees the animated terminal + proof bar + how-it-works → understanding builds.
4. Clicks "Star on GitHub" → repo opens in a new tab; visitor stars.
5. Reaches final CTA → copies the second snippet / re-copies install → installs in their Claude Code.

### Skeptic path

1. Visitor clicks _Why SDLC_ in nav.
2. Scrolls through the five argument sections; the gate rail lights each gate as passed and the sticky pane crossfades its illustration per section.
3. Reads the page FAQ and the "all five gates passed" CTA kicker → converts via CTA, or jumps to full FAQ.

### Content-editor path

1. Editor opens the Payload admin.
2. Edits an FAQ answer (or a "why" paragraph) and saves.
3. Reloads the public page → the updated copy is live; no deploy occurred.
4. Structured data (`FAQPage`) reflects the same answer text.

### Edge cases

- **Reduced motion:** OS setting on → starfield/meteors/cursor-glow/terminal/accordion animations are static or instantaneous; all content still reachable and legible.
- **Fresh database (no CMS content yet):** seed runs → site is fully populated; the app never renders an empty FAQ or missing "why" copy.
- **CMS unreachable / content fetch fails at build or request time:** page renders with a safe fallback (defined in spec) rather than a broken or blank section.
- **Small viewport:** multi-column hero, org chart, and side-by-side comparison reflow to remain readable and usable.
- **Clipboard blocked / unsupported:** copy action fails gracefully with the command still visible/selectable.
- **Jump-scroll on Why SDLC:** gate rail state is derived from scroll position robustly (a section counts as passed when its top crosses the documented viewport fraction), so fast scrolls do not desync the gates.
- **Long CMS copy:** editorial fields that exceed the designed length must not break layout (graceful wrapping/truncation per spec).

## 9. Out of scope (explicit boundaries)

- Rewriting or re-authoring approved design copy — it is final.
- CMS-managing factual/reference content (tooling facts, agent rosters, commands, install snippets) — those stay static in code.
- New stack or framework decisions — `apps/marketing` (Next.js + Payload 3 + Neon) is fixed and final.
- The earlier 3D / three.js hero direction from Epic NA-20 (stories NA-16/17/19/21/22) — this build follows the CSS night-sky handoff, not that approach.
- Photography or bitmap art — illustrations are CSS/text only; the prototype `support.js` runtime is not ported.
- Authoring new SEO copy — values come from `docs/gtm/site-brief.md`; this epic only wires them in.
- Building/standing up analytics infrastructure beyond what an in-scope instrumentation decision (if made) requires.

## 10. Dependencies

Must exist before or alongside this build:

- **`apps/marketing` app** — Next.js + Payload 3 CMS on Neon Postgres (the FINAL stack). Payload must be configured for the CMS-driven collections/globals.
- **Design handoff committed** at `docs/design/marketing-site-handoff/` (README + `designs/` + `tokens/` + `screenshots/`) — done on this branch; authoritative for layout, tokens, copy, and interactions.
- **gtm site brief** at `docs/gtm/site-brief.md` — verified present in repo; authoritative for the SEO layer (meta/OG, JSON-LD, `llms.txt`) and the per-section token mapping.
- **nightshift design tokens** (`tokens/*.css` in the handoff, sourced from `.claude/skills/nightshift-design/`) — the token values to express as Tailwind v4 `@theme` CSS variables.
- **GitHub repo** (`whimzyLive/nightshift-ai`) reachable as the star/CTA target.

### Story Dependency Graph (NA-29 stories)

Canonical build order for the stories under `NA-29`. Jira `Blocks` / `is blocked by` links are kept in sync with this graph.

**Completion order:**

- **L0 (parallel-safe):** NA-30 (site-wide chrome and design tokens), NA-31 (CMS FAQ and editorial why-copy content layer)
- **L1 (parallel-safe once L0 is merged):** NA-32 (home hero/proof/problem), NA-33 (home how-it-works/trust sections), NA-34 (home control section), NA-35 (home FAQ preview + final CTA), NA-36 (Why SDLC page), NA-37 (team page), NA-38 (full FAQ page)
- **L2:** NA-39 (SEO meta, JSON-LD, llms.txt)

**Dependency edges:**

| Blocker | Blocks | Rationale                                                                                                 |
| ------- | ------ | --------------------------------------------------------------------------------------------------------- |
| NA-30   | NA-32  | Home hero/proof/problem renders inside the shared chrome shell and reuses its tokens/CTA/card primitives. |
| NA-30   | NA-33  | Home how-it-works/trust sections reuse the shared chrome primitives (cards, tokens).                      |
| NA-30   | NA-34  | The control section's route lanes/gate strip/terminals reuse the shared chrome primitives.                |
| NA-30   | NA-35  | Home FAQ preview + final CTA reuse the shared chrome accordion/CTA primitives.                            |
| NA-30   | NA-36  | Why SDLC page reuses the shared chrome shell, nav, and card primitives.                                   |
| NA-30   | NA-37  | Team page reuses the shared chrome shell and card primitives.                                             |
| NA-30   | NA-38  | Full FAQ page reuses the shared chrome accordion primitives.                                              |
| NA-31   | NA-35  | Home FAQ preview renders its top-5 entries from the CMS FAQ collection.                                   |
| NA-31   | NA-36  | Why SDLC page's 2-question FAQ renders from the CMS FAQ collection.                                       |
| NA-31   | NA-38  | Full FAQ page renders all 12 entries from the CMS FAQ collection.                                         |
| NA-31   | NA-39  | SEO JSON-LD FAQPage text-identity check needs the CMS content model to exist.                             |
| NA-35   | NA-39  | SEO layer's FAQPage text-identity check needs Home's rendered FAQ copy to exist.                          |
| NA-36   | NA-39  | SEO layer's Why SDLC FAQPage/WebPage JSON-LD needs the page's rendered content to exist.                  |
| NA-38   | NA-39  | SEO layer's FAQPage text-identity check needs the full FAQ page's rendered copy to exist.                 |

## 11. Product checks

- **Roles affected:** prospective adopter, skeptical engineer, content editor/maintainer, plus downstream SDLC phases (spec/plan/impl) that consume the committed handoff.
- **Mobile / offline required:** responsive web required; native mobile app — no; offline mode — no.
- **Surfaces:** web only (`apps/marketing`).

## 12. Open questions (product decisions still needed before/at spec)

1. **NA-29 vs NA-20 reconciliation** — Does this design-handoff epic supersede/replace the existing Epic NA-20 "Marketing Site" and its 3D-hero stories (NA-16/17/19/21/22), or run in parallel? _Owner: Rushi / Product._ (Out-of-scope boundary above assumes supersede for the 3D direction; the formal epic disposition still needs a call.)
2. **Exact CMS content model** — Beyond FAQ entries and the "why use X" paragraphs, which specific paragraphs are CMS-driven vs static? Needs a definitive field-by-field list. _Owner: PRD/Spec phase._
3. **Adoption instrumentation** — Is analytics for install-copy and star click-through in scope for v1, and if so which tool? _Owner: Product._
4. **Fonts** — Self-host Inter + JetBrains Mono for production, or Google Fonts as in the prototype? _Owner: PRD/Spec._
5. **Seed-script ownership and re-seed policy** — Who owns the idempotent CMS seed from approved copy, and what is the re-seed / conflict policy when CMS content has been edited since the last seed? _Owner: PRD/Spec phase._

---

_Design source of truth: `docs/design/marketing-site-handoff/README.md`. SEO layer source of truth: `docs/gtm/site-brief.md`. All copy in the design files is approved and must not be rewritten; FAQ answers must remain text-identical to the `FAQPage` JSON-LD._
