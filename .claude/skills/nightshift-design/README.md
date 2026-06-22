# nightshift — Design System

> 🌙 **Your AI software team that ships while you sleep.**
> A Claude Code plugin that turns one terminal into a full software-delivery team —
> PM, architect, tech lead, engineers, QA — driven straight from your issue tracker.

This project is the design system and marketing/brand toolkit for **nightshift**. It contains
the color/type/spacing token system, brand assets, reusable React components, and full-screen
UI-kit recreations of the marketing site and docs.

---

## Product context

nightshift is a Claude Code **plugin marketplace**. Its flagship plugin, `sdlc`, installs a
repo-agnostic software-delivery team: 11 specialized agents (one per role) and 10 slash commands
that run the whole lifecycle one verb at a time — `/spec`, `/plan`, `/impl`, `/review`, and a
one-shot `/auto <TICKET>`. A Jira ticket goes in; a reviewed PR comes out, with an auditable
artifact at every stage.

**Audience:** senior developers, engineering leads, indie builders. They live in the terminal and
distrust hype. The design must feel **credible, fast, and technical** — never a generic SaaS splash.

**Positioning wedge:** not "AI writes code" (commoditized) but **"AI runs your SDLC with a real
team's discipline."** Lead with the team-of-agents angle. Proof, not adjectives — show the `/auto`
run, never say "powerful/revolutionary."

### Sources
- **GitHub:** [whimzyLive/nightshift-ai](https://github.com/whimzyLive/nightshift-ai) — the plugin
  repo. README, `LAUNCH.md`, and `plugins/sdlc/{agents,commands}` were the source of truth for copy,
  tone, the agent roster, and authentic terminal/command output. Explore it further to build
  higher-fidelity product designs.
- No Figma or design files were provided — the visual system here is an original interpretation of
  the brand brief (nocturnal night-sky, terracotta accent, monospace texture).

---

## Content fundamentals

How nightshift writes. Match this voice in every artifact.

- **Voice: technical peer, not marketer.** Confident, dry, specific. The reader is a senior dev who
  smells hype instantly. Lead with mechanism and proof.
- **Person: "you" for the reader, "it/the agents" for the product.** "You don't lose time writing
  code." "The agents carry zero project specifics." First person is rare and only collective ("we").
- **Casing:** the brand name is always lowercase — **nightshift** (never "Nightshift" or "NightShift").
  Agent and command names are lowercase mono: `product-manager`, `/auto`, `qa-engineer`. Headings are
  sentence case, not Title Case.
- **Numbers as proof.** "11 specialized agents," "10 slash commands," "the middle 20%," "the other
  80%," "install in 60 seconds." Concrete counts beat adjectives.
- **Structure: thesis → mechanism → proof.** State the claim, explain how it works, then show the
  terminal output. The three-ideas pattern ("A team, not a megaprompt") is signature.
- **Mono for anything you'd type.** Commands, agent names, file paths, branch names, and Conventional
  Commit lines all render in JetBrains Mono — that's the "terminal texture."
- **Emoji:** used **sparingly** as section markers in the upstream README (🌙 ⚡ 🧠 👥 🎛️ 🔧). The 🌙
  moon is the one brand-load-bearing glyph. In product UI and the design system, prefer the SVG moon
  mark and mono `//` eyebrows over emoji. Do **not** sprinkle emoji through body copy.
- **Signature phrases:** "ships while you sleep," "a team, not a megaprompt," "generic agents, per-repo
  config," "the lifecycle is the product," "connective tissue," "spec before plan, plan before code,
  review before merge, tests as the gate."
- **Don't:** over-claim ("replaces your team"), use empty intensifiers, or Title-Case the brand.

---

## Visual foundations

The mood is **nocturnal, calm, focused** — work happening quietly while you sleep. Premium dev-tool,
not playful.

- **Palette — dark-mode-first.** A night-sky base of layered navies/blacks (`#08080f` void →
  `#1a1a2e` surface), one warm **terracotta** accent (`#d97757`, Anthropic-aligned) used as the single
  pointing color, **moonlight** off-white text (`#f5f3ef`), and a cool secondary **moonlit indigo**
  (`#7c93f0`) for links/focus, with cyan for data highlights. Semantic colors are terminal-true
  (green `#6ec48a`, amber `#e0a458`, red `#e0656f`). See `tokens/colors.css`.
- **Type.** Pairing of **Inter** (geometric sans — display, headings, body) and **JetBrains Mono**
  (code, labels, UI chrome, eyebrows). Display is 800 weight with tight `-0.02em` tracking. The
  signature label is a mono `// uppercase eyebrow` in terracotta with `0.16em` tracking.
- **Backgrounds.** Flat night fills, never busy. The one decorative motif is a faint **starfield**
  (tiny radial-gradient dots at low opacity) and a soft **moon glow** (a single blurred radial of
  terracotta or indigo) behind hero/feature areas. No photography, no hand-drawn illustration, no
  loud gradients. Keep it fast and quiet.
- **Cards.** `night-600` fill, a **1px hairline border** (`rgba(255,255,255,0.10)`), `--radius-lg`
  (14px) corners, and a deep soft shadow (`--elev-1/2`). On dark, the hairline does the separating —
  shadow alone won't read. Featured cards get an accent ring + glow.
- **Elevation & glow.** Shadows are deep and soft (high blur, dark). The brand's "light in the dark"
  is the **glow** — `--glow-accent` (terracotta ring + halo) for primary buttons and active pipeline
  stages, `--glow-cool` (indigo) for focus.
- **Radius.** 4 → 28px scale; pills for badges. Buttons use `--radius-md` (10px), cards `--radius-lg`.
- **Borders.** Three hairline strengths (`--border-soft/default/strong`) plus an accent border for
  emphasis. Almost everything structural carries a hairline.
- **Animation.** Restrained and quick. `--ease-out` (gentle overshoot-free) at 120–360ms. Buttons lift
  `translateY(-1px)` on hover; cards lift `-2px` + deepen shadow. The one "alive" motion is the
  **streaming terminal** — pipeline lines reveal one at a time, then loop. No bounces, no parallax,
  no infinite decorative loops on content.
- **Hover states.** Lighten the surface (`night-500 → night-400`), brighten text (`muted → strong`),
  and/or warm the border to accent. Primary buttons go `terra-500 → terra-400`.
- **Press states.** Primary buttons darken to `terra-600`; subtle, no shrink.
- **Focus.** `--glow-focus` — a 3px indigo ring. Always visible, never removed.
- **Transparency & blur.** Used for the **sticky nav** (72% night + 14px backdrop blur) and the
  terminal-on-glass install snippet. Sparingly elsewhere.
- **Imagery vibe.** There is essentially no photography. If imagery is ever added, keep it cool, dark,
  and low-key — a night sky, not a sunny office.

---

## Iconography

- **No bundled icon font in the source.** The upstream repo is a CLI plugin — its "icons" are the 🌙
  emoji in the README, macOS terminal **traffic-light dots**, and **Unicode glyphs** used as status
  and flow markers: `→ ↓ ✓ ✗ ● ▌ ⌘ ⌕ //`. These carry most of the iconographic load and are
  authentic to the terminal context — prefer them.
- **UI icon set: [Lucide](https://lucide.dev) (CDN).** For interface chrome that needs real icons
  (search, external-link, copy, chevrons), use Lucide — clean 1.5px-stroke outline icons that match the
  technical, understated aesthetic. Load from CDN: `https://unpkg.com/lucide@latest`. *This is a
  substitution* — the source ships no icon set, so Lucide is the documented closest-fit default.
- **Brand mark:** an original **crescent-moon** logomark (`assets/logomark.svg`) — a terracotta
  crescent with a soft glow and two small moonlight/indigo stars. Used at 28px in nav, larger in hero
  and brand assets. The GitHub `<svg>` mark is inlined where needed (e.g. NavBar stars).
- **Emoji:** only as the occasional README section marker and the 🌙 brand glyph. Not in product body UI.

---

## What's in here (index)

### Root
- `styles.css` — the single entry point consumers link. `@import` manifest only.
- `tokens/` — `colors.css`, `typography.css`, `spacing.css` (radius/elevation/motion), `fonts.css`
  (Inter + JetBrains Mono via Google Fonts), `base.css` (element resets + nocturnal scrollbar).
- `SKILL.md` — Agent-Skills-compatible entry for using this system in Claude Code.

### Brand assets — `assets/`
- `logomark.svg`, `logo.svg` (mark + wordmark), `favicon.svg`
- `og-card.html` (1200×630 social/OG), `readme-banner.html` (1280×320 GitHub header), `logo-card.html`

### Components — `components/` (namespace `window.NightshiftDesignSystem_983007`)
- **core/** — `Button`, `Badge`, `Card`, `InstallSnippet`
- **terminal/** — `Terminal` (+ `TermLine`), `CodeBlock`, `Pipeline`
- **site/** — `NavBar`, `Footer`
- **data/** — `AgentCard`, `CommandCard`, `Table`

Each directory has a `*.card.html` specimen (Design System tab) and each component a `.d.ts` +
`.prompt.md`.

### UI kits — `ui_kits/`
- **marketing/** — the full landing page (hero w/ animated terminal demo, problem, how-it-works,
  11-agent team grid, install, footer).
- **docs/** — the docs home (sidebar nav, content, command-reference cards, project-context sample).

### Foundations — `guidelines/`
Specimen cards for the Design System tab: color (backgrounds, accent, cool, semantic, text), type
(display, body, mono, scale), spacing (scale, radius, elevation).

---

## Caveats
- **Fonts** are loaded from Google Fonts (Inter + JetBrains Mono) rather than self-hosted `.woff2`.
  For offline/production use, self-host and swap `tokens/fonts.css` to `@font-face` rules.
- **Lucide icons** are a documented substitution — the source repo ships no icon set.
- The brand **logomark** is an original interpretation (no logo existed upstream beyond the 🌙 emoji).
