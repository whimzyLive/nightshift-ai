# 🌙 nightshift — brand & positioning kit

The reusable brand reference for every launch asset (landing site, demo, blog,
social). The brand is **locked** — this kit commits it so nothing downstream has
to re-decide it.

> **Source of truth.** The design system lives in
> [`.claude/skills/nightshift-design/`](../.claude/skills/nightshift-design/) —
> color/type tokens in `tokens/*.css` (mirrored in `_ds_manifest.json`), canonical
> assets in `assets/`, UI kit in `components/`, voice in
> `references/voice-and-content.md`. This kit **summarizes and points at** that
> system; it does not restate values as a second source. Never invent a value that
> has a token, and never hand-roll a logo — query `tokens/colors.css` for an exact
> hex and reuse the assets below. Run `npm run validate` in the design-system
> directory before shipping any asset.

---

## Name

- **Name:** `nightshift` — **always lowercase**, even at the start of a sentence.
  Never "Nightshift", "NightShift", or "NS".
- **Agent and command names** are lowercase mono too: `product-manager`, `/auto`,
  `qa-engineer`.
- **Wordmark:** the `shift` half sets in terracotta, the `night` half in moonlight,
  in JetBrains Mono — see assets below. Don't typeset a new wordmark; use the file.

## Tagline

> **you sleep, it ships**

- Always lowercase. This is the **locked** tagline (from the PRD) — don't
  substitute variants in launch copy.
- The voice guide's signature phrase **"ships while you sleep"** is the same idea
  in prose form (e.g. README hero); the lockup tagline stays `you sleep, it ships`.

## Elevator pitch (one line)

> **nightshift is a free Claude Code plugin that turns one terminal into a full
> software-delivery team — it reads a ticket and ships the spec, plan, code, and
> review while you sleep.**

## Positioning

- A **free, MIT-licensed, drop-in** Claude Code plugin — not a paid product, not a
  SaaS, not a code-writing wrapper.
- The wedge is **not** "AI writes code" (commoditized) but **"AI runs your SDLC
  with a real team's discipline"** — lead with the team-of-agents angle.
- A **process engine**: spec before plan, plan before code, review before merge,
  tests as the gate. The lifecycle is the product.
- **Issue-tracker native, repo-agnostic** — generic agents, per-repo config.

**Proof beats adjectives:** 11 specialized agents, 10 slash commands, one `/auto`
run, install in 60 seconds. Show the terminal output, not superlatives.

---

## Assets (canonical — mirrored from the design system)

These are verbatim mirrors of `.claude/skills/nightshift-design/assets/` (the
source of truth). Regenerate from there; don't edit copies here.

| Asset | File | Use |
| --- | --- | --- |
| Wordmark lockup (dark bg) | [`assets/logo.svg`](./assets/logo.svg) | landing hero, README header, social-preview card — on dark surfaces |
| Wordmark lockup (light bg) | [`../.claude/skills/nightshift-design/assets/logo-light.svg`](../.claude/skills/nightshift-design/assets/logo-light.svg) | the same lockup for light/white surfaces — "night" in `--night-800` ink, "shift" in terracotta. Lives in the design system only |
| Moon mark | [`assets/logomark.svg`](./assets/logomark.svg) | favicon-scale mark, nav (28px), avatar |
| Favicon | [`assets/favicon.svg`](./assets/favicon.svg) | site favicon |

Visual identity is intentionally **minimal** (per scope): the 🌙 crescent + warm
glow + monospace type. No full design-system rebuild here, no Pro-tier branding.

## Color palette

Exact values + semantic aliases live in
[`tokens/colors.css`](../.claude/skills/nightshift-design/tokens/colors.css). The
launch-relevant subset:

| Role | Token | Hex |
| --- | --- | --- |
| Page background | `--night-800` | `#0d0d18` |
| Deepest void | `--night-900` | `#08080f` |
| Card / surface | `--night-600` | `#1a1a2e` |
| Terminal surface | `--surface-terminal` | `#0b0b14` |
| Primary text (warm off-white) | `--moon-100` | `#f5f3ef` |
| Body text | `--moon-200` | `#d8d6e0` |
| Muted text | `--moon-300` | `#a9a7bd` |
| **Brand accent (terracotta)** | `--terra-500` | `#d97757` |
| Accent hover / press | `--terra-400` / `--terra-600` | `#e58b6f` / `#c2624a` |
| Links / focus (indigo) | `--indigo-400` / `--indigo-500` | `#8b9cf7` / `#7c93f0` |
| Data / info (cyan) | `--cyan-400` | `#62c4d3` |
| success / warning / danger | `--green-400` / `--amber-400` / `--red-400` | `#6ec48a` / `#e0a458` / `#e0656f` |

- **One pointing color:** terracotta `--terra-500` is the single brand accent —
  one accent per view. Indigo, cyan, and the semantic colors are functional
  (links/focus, data, state), not decorative.
- Use the **semantic aliases** (`--bg-page`, `--surface-card`, `--accent`,
  `--text-strong`, …) in components, not raw scale values.

## Typography

Tokens in
[`tokens/fonts.css`](../.claude/skills/nightshift-design/tokens/fonts.css) +
`typography.css`.

- **Headings & body:** Inter (`--font-sans`). Headings are **sentence case**, never
  Title Case.
- **Anything you'd type** — commands, agent names, file paths, branch names,
  Conventional Commit lines: JetBrains Mono (`--font-mono`). That's the terminal
  texture. Section eyebrows use mono `//`, e.g. `// how it works`.

---

## Voice & tone

Technical peer, not marketer. Confident, dry, specific. Lead with mechanism and
proof. Full guide:
[`references/voice-and-content.md`](../.claude/skills/nightshift-design/references/voice-and-content.md).

**Do**

- Write to a senior dev who lives in the terminal and distrusts hype.
- Structure: **thesis → mechanism → proof.** State the claim, explain how it
  works, then show the `/auto` run.
- Use numbers as proof: "11 agents, 10 commands," "the middle 20% / the other 80%,"
  "install in 60 seconds."
- Say it's **free** and **open source** plainly — that's a feature.
- Reuse the signature phrases: "ships while you sleep", "a team, not a megaprompt",
  "generic agents, per-repo config", "the lifecycle is the product", "connective
  tissue", "spec before plan, plan before code, review before merge, tests as the
  gate".

**Don't**

- Over-claim: "replaces your team", "powerful", "revolutionary", "next-gen", "the
  future of coding".
- Empty intensifiers or hype adjectives — show the run instead.
- Title-case the brand, or restyle the wordmark / swap the tagline.
- Sprinkle emoji through body copy — the 🌙 moon is the one load-bearing glyph; in
  product UI prefer the SVG moon mark.

---

## Approved short-form copy (tweet-length)

Reuse verbatim or riff within the voice rules above. **No agent invents brand copy
outside this kit.**

1. you sleep, it ships. 🌙 nightshift is a free Claude Code plugin that turns one
   terminal into a full software-delivery team — `product-manager`,
   `solutions-architect`, `tech-lead`, engineers, `qa-engineer` — driven from your
   issue tracker.

2. AI assistants nail the middle 20% — the code. nightshift runs the other 80%:
   your SDLC, with a real team's discipline. spec → plan → implement → review → PR,
   from a ticket. free, MIT.

3. ticket in, reviewed PR out. nightshift reads the issue, writes the spec, plans
   the work, implements it, and reviews it before merge — in any repo. a team, not
   a megaprompt.

4. it's not "AI writes code." it's AI that runs your lifecycle: spec before plan,
   plan before code, review before merge, tests as the gate. 11 agents, 10
   commands, one `/auto`. open source.

5. install in 60 seconds, point it at a ticket, come back to a reviewed PR. generic
   agents, per-repo config — install once, use everywhere. that's nightshift. 🌙

---

## Dependents

Every downstream launch asset pulls name, tagline, pitch, palette, wordmark, and
copy from this kit and the design system — never reinvents them:

- landing site on the brand domain
- 90-second launch demo video
- launch blog article (and cross-posts)
- launch-day social blast
- Show HN / Product Hunt / Reddit assets
- README SEO / social-preview card
- newsletter and aggregator submissions

> When a downstream story starts, link it back to this kit so the dependency is
> explicit on both sides.
