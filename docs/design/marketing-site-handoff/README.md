# Handoff: nightshift marketing site

## Overview

A four-page marketing site for **nightshift** — a free, MIT-licensed Claude Code plugin that runs a full software-delivery lifecycle (spec → plan → implement → review) from a Jira ticket. The site's job is adoption: get a visitor to copy the two-line install command and star the repo.

Pages:

1. **Home / landing** (`designs/nightshift Landing.dc.html`) — long-scroll conversion page
2. **Why SDLC** (`designs/why-sdlc.dc.html`) — positioning argument page with scroll-lit gates + sticky visual pane
3. **The team** (`designs/team.dc.html`) — company-style team page built around the agent org
4. **FAQ** (`designs/faq.dc.html`) — grouped accordion FAQ

Target implementation home: **`apps/marketing` in whimzyLive/nightshift-ai** (Next.js). If that app is not the target, choose the framework the repo already standardizes on.

## About the Design Files

The files in `designs/` are **design references created in HTML** — interactive prototypes showing intended look and behavior, **not production code to copy directly**. They are authored as "Design Component" documents: the markup lives inside an `<x-dc>` tag and the behavior in a `class Component` script block at the bottom of each file, rendered by the bundled `support.js` runtime. Ignore the runtime; read the files for:

- **Markup + inline styles** inside `<x-dc>` — the exact layout, spacing, colors, and typography
- **`<helmet><style>`** — global CSS (starfield, glass nav, sharp-edge overrides, neon buttons, keyframes)
- **The `class Component` block** — all interaction logic in plain readable JS (state, timers, scroll handlers, data arrays)
- **`{{ placeholders }}`** — dynamic values; their computation is in the component class `renderVals()`

The task is to **recreate these designs in the target codebase** (React/Next.js components, CSS modules or Tailwind — whatever the repo uses), matching them pixel-perfectly.

## Fidelity

**High-fidelity.** Colors, typography, spacing, copy, and interactions are final. Recreate the UI pixel-perfectly. All copy in the designs is approved copy — do not rewrite it.

## Design Tokens

Authoritative token files are in `tokens/` (colors, typography, spacing, fonts, base resets) — they come from the repo's own design system at `.claude/skills/nightshift-design/`. Key values:

- **Backgrounds:** page `--night-800 #0d0d18`, void `--night-900 #08080f`, card `--night-600 #1a1a2e`, terminal `#0b0b14`
- **Text:** strong `--moon-100 #f5f3ef`, body `--moon-200 #d8d6e0`, muted `--moon-300 #a9a7bd`
- **Accent (single pointing color):** terracotta `--terra-500 #d97757`, hover `--terra-400 #e58b6f`, press `--terra-600 #c2624a`
- **Functional:** links/focus indigo `#8b9cf7 / #7c93f0`, data cyan `#62c4d3`, success `#6ec48a`, warn `#e0a458`, danger `#e0656f`
- **Type:** Inter (headings 800 weight, `-0.025em` tracking, sentence case; body 400) + JetBrains Mono (anything you'd type: commands, agent names, paths, eyebrows). Section eyebrows: mono, 12–13px, `0.16em` tracking, uppercase, terracotta, `//` prefix
- **Edges: SHARP.** `border-radius: 0` on every rectangle (cards, buttons, pills, terminal frames). Only circles (star dots, gate circles, traffic lights) stay round. This intentionally overrides the design system's radius tokens
- **Brand casing:** `nightshift` always lowercase. Agent names and commands lowercase mono

## Site-wide chrome (all four pages)

- **Night-sky background** — fixed full-viewport layer behind content: multi-depth starfield (3 parallax layers on home; static CSS gradients on subpages), faint terracotta/indigo halo glows. Home only: a glowing crescent moon (~110px, top right of hero), periodic meteors streaking diagonally opposite their tails, click-to-spawn meteors on empty areas, and mouse-parallax on the star layers
- **Glass nav** — translucent gradient + `backdrop-filter: blur(20px) saturate(1.35)`, hairline bottom border. Past the hero (~320px scroll) it detaches into a floating **sharp-cornered** bar: `top:14px`, `max-width:min(940px, 100% - 48px)`, centered, `blur(26px)`, deep shadow + faint terracotta ring. Links: How it works (home#how-it-works) · Why SDLC · The team · FAQ · GitHub · primary CTA "Install the plugin"
- **Glass footer** — translucent over the sky. Columns: Plugin / Project / Company. Footer links `display:block; line-height:1.6`
- **Cursor glow** — 28px radial terracotta glow following the pointer (`mix-blend-mode:screen`), growing to 84px over links/buttons/cards. Desktop pointer only; disabled under `prefers-reduced-motion`
- **Neon CTA buttons (inverted)** — rest: `rgba(217,119,87,.08)` fill, terracotta border + text, glow `0 0 16px rgba(217,119,87,.42), 0 0 38px rgba(217,119,87,.18)`. Hover: solid terracotta fill, **white `#f5f3ef` text**, and a 3-layer stacked offset shadow (`4px 4px`, `8px 8px`, `12px 12px` terracotta at falling opacity). Press: `--terra-600`
- **Heading glow** — wide-halo text-shadow only (`0 0 28px` white + `0 0 64px` indigo at low alpha); never within ~8px of glyph edges (keeps type crisp). Body text gets a tight `0 1px 2px` dark shadow
- **Hover-lift cards** — border warms to accent, `translateY(-3px)`, soft glow shadow
- All motion honors `prefers-reduced-motion`

## Screens / Views

### 1. Home (10 sections, in order)

1. **Hero** — two-column (1fr : 1.12fr). Left: badges (`v0.4.0 · MIT`, `a Claude Code plugin`), H1 "Your AI software team that ships while you sleep" (clamp 40–60px, "while you sleep" is a terracotta link to #workflow), subhead, mono pipeline line `Jira ticket → spec → plan → implementation → review → PR`, "Install in 60 seconds" label + two copyable install snippets (`/plugin marketplace add whimzyLive/nightshift-ai`, `/plugin install sdlc@nightshift`), secondary "★ Star nightshift on GitHub". Right: animated terminal (~420px min-height) playing a scripted `/auto PROJ-142` run line-by-line (~520ms cadence, loops after 4.2s pause); magnetic 3D tilt toward cursor on hover (±4°), ambient drift otherwise. A "you sleep, it ships ✦" mono marquee strip runs below the hero
2. **Proof bar** — `11 specialized agents · 10 slash commands · install in 60 seconds · free · MIT`, mono, numbers terracotta, animated count-up on first view
3. **Problem** — "You don't lose time ~~writing code~~. You lose it _around the code_." + three sub-point cards
4. **How it works** — pipeline component, `/auto PROJ-142` snippet, 5-step labeled table (step numbers terracotta), "Drive a stage yourself" note (`/spec /plan /impl /review`), GitHub link
5. **Review by day, ship by night** (`#workflow`) — Day / Night / Morning cards, night card accent-ringed
6. **The team** (`#agents`) — terminal tree (`$ nightshift --team --tree`): box-drawing tree of `you (human)` → six gated phases (⊘ + phase + command verbs) → agent stars, with L5 implement nesting principal-engineer → 5 domain agents. Hovering any row updates a sticky side panel (charter, artifact, repo source link); unrelated rows dim. Below: link "Meet the whole team — charters, handoffs, org chart →" to the team page
7. **Why builders choose it** — 4 value cards
8. **You decide how it gets built** (control section) — three connected interactives sharing one state machine: **(a) triage router**: PROJ-142 ticket card with story/bug toggle + points slider (1–13), `project-context.md` config card with `lightweight_threshold` stepper and `approval_mode` cycle button (assisted → auto → full-auto); three route lanes (full ceremony / lightweight / defect) light up per config, decision console narrates the verdict. **(b) route-aware gate strip**: gates for the current route (5 / 3 / 2), pulsing at the awaiting gate. **(c) comparison terminals** (side-by-side, ≥480px tall): left "one-shot AI" plays once — long thinking, diff-blob slam, `✗` failures, "read all 4,213 lines"; right "🌙 nightshift · <route>" is driven by the gate state: triage line (cyan), artifact lines per approved gate, approve ✓ button inside the terminal (assisted: per-phase verbs `/refine-issue`, `/spec`… as prompts; auto: `/auto` + auto-approve except spec/review; full-auto: loops). Bridge link "Why an SDLC beats one-shot AI →"
9. **FAQ (top 5)** — accordion on a solid card (one open, +/− glyphs, animated max-height), then "Browse the full FAQ — workflow, setup, trust, licensing →"
10. **Final CTA** — "Put a ticket in tonight. Read a reviewed PR in the morning." + install snippets + star button

### 2. Why SDLC

Breadcrumb `Home / Why SDLC`. Hero + five argument sections as solid cards (66ch measure, 17px/1.75) in a grid: left **gate rail** (dashed terracotta line + one gate node per section — pulsing ⊘ when current, ✓ once scrolled past; driven by scroll position, robust to jump-scrolls: passed when section top < 70% viewport) and right **sticky visual pane** (400px, sticky top:100px) crossfading five mono illustrations per active section (one-shot blob / epic-story tree / vertical gates / blob-vs-artifacts / verb-per-phase terminal) with an `n/5` caption bar. Page FAQ (2 questions) + CTA whose kicker line turns green `✓ ✓ ✓ ✓ ✓ — all five gates passed. The argument survived your review.` once everything was read.

### 3. The team

Hero ("Meet the team that works while you sleep", stats `11 agents on staff · 1 opt-in specialist · hallucinating across roles: not permitted`), 4-card philosophy strip, then an **org chart**: green-bordered YOU card top-center, dashed terracotta spine down through five department clusters (Product, Architecture & Planning, Engineering, Quality, On contract), each with a centered sharp pill label (`// product` — `white-space:nowrap`) and hanging profile cards. Each card: mono initials (tier-colored), name, human title, model-tier badge (**OPUS** terracotta / **SONNET** indigo / **HUMAN** green — from the agents' real frontmatter), charter summary, flow line, artifact (cyan), an italic one-liner "fact", and `charter ↗` linking to the agent's actual `.md` under `plugins/sdlc/agents/`. Then the "company handbook" terminal (6 numbered steps incl. project overrides `.claude/project/agents/<you>.md`) and the "Hire the whole team in 60 seconds" CTA.

### 4. FAQ

Hero + twelve questions in five eyebrow groups (`// positioning`, `// workflow & control`, `// setup & stack`, `// trust & quality`, `// cost & license`), each group a solid-card accordion, numbered Q.01–Q.12 continuously, one answer open across the whole page, install CTA at the bottom.

## Interactions & Behavior (summary)

- All animations 120–400ms, `ease-out`; accordion max-height `.4s`; gate/crossfade `.4–.45s`
- Terminal typing cadence ~520ms/line; gate "working" phase ~1.7s before awaiting; full-auto auto-approves after ~0.7s and loops with a 3.2s pause
- Copy-to-clipboard on install snippets (component behavior)
- Star buttons / nav CTA open the GitHub repo in a new tab
- Scroll handlers are passive; state derives from `getBoundingClientRect()` vs viewport fractions (see each page's component class for exact thresholds)

## State Management

Each page's `class Component` block is the spec: home holds the terminal line index, triage config (`storyPts`, `thresh`, `ticketType`, `approvalMode`), gate machine (`gI`, `gS`, `gDone`), one-shot step, FAQ open index, tree hover; why-sdlc holds `reached` (monotonic) + `active`; faq holds the open key. No server data — everything is static content + client state.

## Assets

- `designs/assets/logomark.svg` (nav/footer, 26–28px), `logo.svg` (wordmark), `favicon.svg` — from the repo's design system; never retypeset the wordmark
- Fonts: Inter + JetBrains Mono via Google Fonts (`tokens/fonts.css`); self-host for production
- No photography anywhere; illustrations are CSS/text only

## SEO / build extras (from the site brief, not in the prototypes)

The gtm site brief (`docs/gtm/site-brief.md` in the repo) carries the meta/OG tags, JSON-LD (`SoftwareApplication` + `FAQPage` + `HowTo`, plus per-page `WebPage`/`BreadcrumbList`), and `llms.txt` — wire those in at build time. FAQ page answers must stay text-identical to any `FAQPage` schema.

## Files

- `designs/nightshift Landing.dc.html` — home (markup, styles, all interaction logic)
- `designs/why-sdlc.dc.html`, `designs/team.dc.html`, `designs/faq.dc.html`
- `designs/support.js` — prototype runtime only; do not port
- `tokens/*.css` — authoritative design tokens
- `screenshots/` — reference captures per page at key scroll positions (`01-home.png` … `06-home.png`, `01-why-sdlc.png` …, `01-team.png` …, `01-faq.png` …). Note: static captures can't show the animated sky, cursor glow, or interactions — the HTML files remain the behavioral source of truth
- Open any design file directly in a browser to interact with it while implementing

## Suggested Claude Code workflow

1. Drop this folder into the repo (e.g. `docs/design/marketing-site-handoff/`).
2. Since the repo runs nightshift itself: `/refine-feature Implement the marketing site per docs/design/marketing-site-handoff/README.md — pixel-perfect recreation of the four HTML design references in apps/marketing` → then let `/auto` run the resulting stories through spec → plan → implement → review. Point the spec at this README and the design files as the source of truth.
3. Or drive it directly: open Claude Code in the repo and prompt: _"Read docs/design/marketing-site-handoff/README.md and the four HTML files in designs/. Recreate them pixel-perfectly as pages in apps/marketing using the existing Next.js setup — one component per section, tokens from tokens/_.css as CSS variables, all interactions per the component classes in the design files."\* Review page-by-page against the prototypes opened side-by-side.
