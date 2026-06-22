---
name: nightshift-design
description: Use when designing, building, writing, OR validating any nightshift interface, marketing page, doc, slide, mock, prototype, or brand asset — covers the night-sky dark theme, terracotta accent, Inter + JetBrains Mono type, design tokens, React UI-kit components, the technical no-hype brand voice, and a runnable adherence gate (token-drift + WCAG-AA contrast + lint). Trigger on "nightshift", "design with the brand", "terminal/pipeline UI", "ships while you sleep", "check brand adherence", "validate nightshift design".
user-invocable: true
---

# nightshift — Design System

## Overview

**nightshift** is a Claude Code plugin that turns one terminal into a full AI software-delivery team — PM, architect, tech lead, engineers, QA — driven from the issue tracker. Tagline: **"Your AI software team that ships while you sleep."**

The design is **nocturnal, calm, technical, no-hype**. Audience is senior devs who live in the terminal and smell marketing instantly. Every artifact must feel **credible, fast, technical** — a premium dev-tool, never a generic SaaS splash. **Lead with proof (terminal output, numbers), never adjectives.**

**The brand name is always lowercase — `nightshift`.** Never "Nightshift" or "NightShift".

## When to Use

- Building nightshift UI (production React, or static HTML mocks/slides/prototypes)
- Writing nightshift copy (landing page, docs, README, social)
- Producing brand assets (OG cards, banners, logo lockups)
- Any artifact that must match the brand

**Two output modes** (ask which if unclear):
1. **Throwaway visual** (slide, mock, prototype) → copy assets out, emit static HTML files the user can open.
2. **Production code** → read the token CSS + component sources, design as a brand expert.

If invoked with no guidance, ask what they want to build, ask a few sharp questions, then act as the expert designer.

## Build workflow — follow every time

1. **Load the relevant reference(s)** below before writing any UI. Don't design from memory of this summary — the detail files carry exact values. Token values are authoritative in `tokens/*.css`, mirrored machine-readable in `_ds_manifest.json` — **query the manifest for an exact hex, never guess one.**
2. **Use DS components** (`references/components.md`) where they exist; hand-build only the rest, following `references/patterns.md` recipes. Never invent a value that has a token.
3. **Start static mocks** from `templates/page-starter.html` (inherits all tokens + signature motifs); diff against `ui_kits/marketing` + `ui_kits/docs` as the golden full-page references.
4. **Gate before done:** run `npm run validate` (token-drift + WCAG-AA contrast + oxlint), then walk `references/adherence-checklist.md` for the human-only checks. Every box passes or is deliberately N/A.

## Reference files (read on demand)

| Need | File |
|------|------|
| Every token, exact value, semantic alias, base resets | `references/tokens.md` |
| Every component's full props/usage + product data (agents, commands) | `references/components.md` |
| Brand voice, casing, signature phrases, do/don't copy | `references/voice-and-content.md` |
| Recipes: hero, card, button, starfield, moon-glow, page scaffold, icons | `references/patterns.md` |
| Pre-ship adherence checklist | `references/adherence-checklist.md` |
| Copy-paste static page starter | `templates/page-starter.html` |

The raw source of truth still lives in `tokens/`, `components/`, `guidelines/`, `ui_kits/`, `assets/` — read those for deepest fidelity.

## Content voice — match in every artifact

- **Technical peer, not marketer.** Confident, dry, specific. Lead with mechanism and proof.
- **Person:** `"you"` for the reader; `"it"/"the agents"` for the product. First person rare, only collective ("we").
- **Casing:** brand `nightshift` always lowercase. Agent/command names lowercase mono: `product-manager`, `/auto`, `qa-engineer`. Headings **sentence case**, never Title Case.
- **Numbers as proof:** "11 specialized agents," "10 slash commands," "install in 60 seconds." Concrete counts beat adjectives.
- **Structure:** thesis → mechanism → proof. Claim it, explain how, then show terminal output.
- **Mono for anything you'd type:** commands, agent names, file paths, branch names, Conventional Commit lines → JetBrains Mono. That's the "terminal texture."
- **Signature phrases:** "ships while you sleep," "a team, not a megaprompt," "generic agents, per-repo config," "the lifecycle is the product," "spec before plan, plan before code, review before merge, tests as the gate."
- **Emoji:** sparingly. The 🌙 moon is the one brand glyph. In product UI prefer the SVG moon mark + mono `//` eyebrows over emoji. Never sprinkle emoji through body copy.
- **Don't:** over-claim ("replaces your team"), use empty intensifiers ("powerful/revolutionary"), or Title-Case the brand.

## Design tokens (quick reference)

Import the single entry point: `styles.css` (`@import` manifest of `tokens/*.css`). Use **semantic aliases** in components, not raw scale values. **Exact hex values are not listed here on purpose** — they live once in `tokens/colors.css` (mirrored in `_ds_manifest.json`); read them there so this summary can't drift. `npm run check:tokens` fails the build if any doc hex stops matching the CSS.

### Color — dark-mode-first (semantic aliases — use these, not raw scale)
| Role | Alias |
|------|-------|
| Page / void / sunken bg | `--bg-page` · `--bg-void` · `--bg-sunken` |
| Surfaces | `--surface-card` · `--surface-raised` · `--surface-overlay` · `--surface-terminal` |
| Accent (the one pointing color) | `--accent` · `--accent-hover` · `--accent-press` (terracotta) |
| Link / focus (cool indigo) | `--link` · `--link-hover` · `--focus-ring` |
| Text | `--text-strong` · `--text-body` · `--text-muted` · `--text-dim` · `--text-on-accent` |
| States | `--success` · `--warning` · `--danger` · `--info` (terminal-true) |
| Hairlines | `--border-soft` · `--border-default` · `--border-strong` · `--border-accent` |
| Code syntax | `--code-comment/-keyword/-string/-fn/-num/-punct/-prompt` |

Exact values + raw scale (`--night-*`, `--terra-*`, `--moon-*`, `--indigo-*`) → `references/tokens.md` or `tokens/colors.css`.

### Type — Inter + JetBrains Mono
- `--font-sans` Inter — display, headings, body. `--font-mono` JetBrains Mono — code, labels, UI chrome, eyebrows.
- Display: `--fw-extra` (800), tracking `--tracking-tight` (-0.02em).
- **Signature eyebrow:** mono, uppercase, terracotta, `--tracking-eyebrow` (0.16em) — e.g. `// HOW IT WORKS`.
- Scale: `--text-2xs`11 · `xs`12 · `sm`13 · `base`15 · `md`17 · `lg`20 · `xl`25 · `2xl`32 · `3xl`42 · `4xl`56 · `5xl`72 · `6xl`92 (px).
- Leading: `tight`1.06 `snug`1.22 `normal`1.5 `relaxed`1.65.

### Spacing / radius / elevation / motion
- **Spacing:** 4px base — `--space-1..32` (4,8,12,16,20,24,32,40,48,64,80,96,128).
- **Radius:** `xs`4 `sm`6 `md`10 (buttons) `lg`14 (cards) `xl`20 `2xl`28 `pill`999.
- **Elevation:** deep soft shadows `--elev-1..4`. On dark, **always pair shadow with a 1px hairline** — shadow alone won't read.
- **Glow** (the "light in the dark"): `--glow-accent` (terracotta, primary buttons + active pipeline stages), `--glow-cool` (indigo focus), `--glow-focus` (3px indigo ring — always visible, never removed).
- **Motion:** `--ease-out` cubic-bezier(.22,1,.36,1) at `--dur-fast`120 / `--dur-base`200 / `--dur-slow`360ms. Restrained, quick.
- **Layout:** `--container-max`1200 · `--container-prose`720 · `--nav-height`64.

## Components

React, namespace `window.NightshiftDesignSystem_983007`. Each component has a `.d.ts` + `.prompt.md` (read for full API); each group a `*.card.html` specimen.

| Group | Components |
|-------|-----------|
| core/ | `Button`, `Badge`, `Card`, `InstallSnippet` |
| terminal/ | `Terminal` (+ `TermLine`), `CodeBlock`, `Pipeline` |
| site/ | `NavBar`, `Footer` |
| data/ | `AgentCard`, `CommandCard`, `Table` |

`Button` example — variants `primary` (filled terracotta + glow) · `secondary` (raised + hairline) · `ghost` (text, fills on hover) · `danger` (red outline); sizes `sm|md|lg`; props `mono` (command labels), `loading`, `disabled`, `iconLeft/iconRight`, `fullWidth`:
```jsx
<Button variant="primary" size="md">Install plugin</Button>
<Button variant="ghost" mono>/auto</Button>
```

## Signature moves (do these to read as nightshift)

- Mono `// uppercase eyebrows` in terracotta above section headings.
- The **terminal window** surface (traffic-light dots, `--surface-terminal`) with streaming `/auto` pipeline output — lines reveal one at a time, then loop. The one "alive" motion.
- Faint **starfield** (tiny low-opacity radial dots) + soft **moon glow** (single blurred terracotta/indigo radial) behind heroes. No photography, no loud gradients.
- **Glow** on primary buttons and active pipeline stages.
- **Hairline border on every card** — `--surface-card` fill, `--radius-lg`, deep soft shadow, hairline does the separating. Featured cards get accent ring + glow.
- Hover lifts (`translateY(-1px)` buttons, `-2px` cards) + warms border to accent.
- Unicode flow glyphs from the terminal: `→ ↓ ✓ ✗ ● ▌ ⌘ //`. Real UI icons → **Lucide** (1.5px stroke, CDN) — a documented substitution; source ships no icon set.
- Brand mark: crescent-moon `assets/logomark.svg` (terracotta crescent, soft glow, two stars), 28px in nav.

## Common mistakes

- Title-casing the brand → always `nightshift`.
- Marketing adjectives ("powerful", "revolutionary") → show the `/auto` run instead.
- Shadow with no hairline on dark → invisible card edge. Always add the 1px border.
- Removing focus ring → keep `--glow-focus` always visible.
- Emoji in body UI → use the SVG moon mark + mono `//` eyebrows.
- Light-mode assumptions → this system is dark-first.

## File index

- `references/` — agent-facing digest: `tokens.md`, `components.md`, `voice-and-content.md`, `patterns.md`, `adherence-checklist.md`.
- `templates/page-starter.html` — copy-paste static page wired to the tokens + signature motifs.
- `_ds_manifest.json` — **authoritative machine index**: every token (with `definedIn`), component, asset. Query for exact values instead of guessing.
- `package.json` + `scripts/check-tokens.mjs` + `scripts/check-contrast.mjs` — the `npm run validate` gate: token-drift, WCAG-AA contrast, oxlint (`_adherence.oxlintrc.json`).
- `styles.css` → `tokens/` — `colors.css`, `typography.css`, `spacing.css` (radius/elevation/motion), `fonts.css`, `base.css`.
- `components/{core,terminal,site,data}/` — `.jsx` + `.d.ts` + `.prompt.md` + group `*.card.html`.
- `guidelines/*.card.html` — color/type/spacing specimen cards.
- `ui_kits/marketing/` and `ui_kits/docs/` — full-page references (hero, agent grid, install, docs sidebar).
- `assets/` — `logomark.svg`, `logo.svg`, `favicon.svg`, `og-card.html`, `readme-banner.html`, `logo-card.html`.
- `README.md` — full brand brief and product context. Source of truth: [whimzyLive/nightshift-ai](https://github.com/whimzyLive/nightshift-ai).

**Caveats:** fonts via Google Fonts (self-host for production); Lucide + logomark are documented original substitutions.
