# nightshift — patterns & recipes

Build order: **tokens → components → these recipes**. Never invent values; compose tokens. The signature decorative motifs (starfield, moon-glow) aren't in the token files — copy them from here verbatim.

## Page scaffold (every page)
1. Link `styles.css` (pulls fonts + all tokens + base resets). See `templates/page-starter.html`.
2. `--bg-page` canvas. Content width `--container-max` (1200) for marketing, `--container-prose` (720) for docs/text.
3. Sticky `NavBar` (translucent + blur) → hero → sections → `Footer` (on `--bg-void`).
4. Section rhythm: vertical padding `--space-20`/`--space-24`; each section opens with a `.ns-eyebrow` `// LABEL`.

## Hero recipe
- `.ns-eyebrow` → display headline (Inter 800, `--text-5xl`/`6xl`, `--tracking-tight`, `--text-strong`) → one body line (`--text-md`, `--text-muted`) → primary `Button` + `InstallSnippet`.
- Behind it: **moon-glow** + **starfield** (below). Beside/below: a `Terminal` streaming `/auto` output — the proof.
- Keep it quiet. One accent focal point.

## Moon-glow (soft radial behind hero/feature)
```css
.ns-moonglow {
  position: absolute; inset: 0; z-index: 0; pointer-events: none;
  background:
    radial-gradient(60% 50% at 70% 20%, rgba(217,119,87,0.16), transparent 70%),
    radial-gradient(45% 40% at 20% 0%, rgba(124,147,240,0.12), transparent 70%);
  filter: blur(8px);
}
```
One blurred radial of terracotta (or indigo). Never loud. Content sits at `z-index:1`.

## Starfield (faint texture)
```css
.ns-starfield {
  position: absolute; inset: 0; z-index: 0; pointer-events: none; opacity: 0.5;
  background-image:
    radial-gradient(1px 1px at 20% 30%, rgba(255,255,255,0.35), transparent),
    radial-gradient(1px 1px at 65% 15%, rgba(255,255,255,0.25), transparent),
    radial-gradient(1px 1px at 85% 55%, rgba(255,255,255,0.30), transparent),
    radial-gradient(1px 1px at 40% 75%, rgba(255,255,255,0.20), transparent),
    radial-gradient(1px 1px at 10% 60%, rgba(255,255,255,0.22), transparent);
  background-repeat: no-repeat;
}
```
Tiny low-opacity dots. Static — no twinkle/parallax on content.

## Card recipe (hand-built, when not using `<Card>`)
```css
.ns-card {
  background: var(--surface-card);
  border: 1px solid var(--border-default);   /* REQUIRED on dark */
  border-radius: var(--radius-lg);
  box-shadow: var(--elev-2);
  padding: var(--space-6);
  transition: transform var(--dur-base) var(--ease-out), box-shadow var(--dur-base) var(--ease-out);
}
.ns-card:hover { transform: translateY(-2px); box-shadow: var(--elev-3); }   /* interactive only */
.ns-card--featured { box-shadow: var(--glow-accent); border-color: var(--border-accent); }
```

## Button recipe (hand-built)
```css
.ns-btn-primary {
  background: var(--accent); color: var(--text-on-accent);
  font-weight: var(--fw-semibold); border: none;
  border-radius: var(--radius-md); padding: var(--space-3) var(--space-5);
  box-shadow: var(--glow-accent);
  transition: transform var(--dur-fast) var(--ease-out), background var(--dur-fast) var(--ease-out);
}
.ns-btn-primary:hover { background: var(--accent-hover); transform: translateY(-1px); }
.ns-btn-primary:active { background: var(--accent-press); transform: none; }
```

## Eyebrow (signature label)
Use the shipped class: `<div class="ns-eyebrow">// HOW IT WORKS</div>`. Mono, uppercase, terracotta, 0.16em tracking.

## Terminal-on-glass (install snippet / nav)
Translucent night + backdrop blur: `background: rgba(13,13,24,0.72); backdrop-filter: blur(14px); border-bottom: 1px solid var(--border-default);`

## Streaming terminal motion (the one "alive" thing)
Pipeline lines reveal one at a time, then loop. `--ease-out`, ~`--dur-slow` per line. No bounces, no parallax, no infinite decorative loops on content.

## Icons
- Terminal/flow glyphs (prefer): `→ ↓ ✓ ✗ ● ▌ ⌘ ⌕ //`.
- Real UI icons: **Lucide** (1.5px stroke), CDN `https://unpkg.com/lucide@latest`. Documented substitution — source ships no icon set.
- Brand mark: `assets/logomark.svg` (terracotta crescent + glow + 2 stars), 28px in nav.

## Hard "always / never"
- **Always** pair a hairline border with any card/shadow on dark.
- **Always** keep `--glow-focus` on focusable elements (never `outline:none` alone).
- **Always** mono for commands/agents/paths.
- **Never** Title-Case the brand; **never** add a second accent color (terracotta is the only pointing color; indigo is for links/focus/info, not decoration).
- **Never** light backgrounds — dark-mode-first.
- **Never** hardcode a hex that has a token.
