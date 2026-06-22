# nightshift — adherence checklist

Run this before shipping ANY generated UI/artifact. Every box must pass or be deliberately N/A.

**🤖 = enforced by `npm run validate`** (token-drift, WCAG-AA contrast, oxlint). Run it first; it turns the marked boxes green automatically. The unmarked boxes are human/agent judgment — walk them by hand.

## Tokens
- [ ] 🤖 All colors come from tokens — no raw hex that has a token. *(`check:tokens` + oxlint)*
- [ ] Semantic aliases used (`--surface-card`, not `--night-600`) in component code.
- [ ] Dark-mode-first: page on `--bg-page`, no light surfaces.
- [ ] Terracotta `--accent` is the ONLY pointing color; indigo only for links/focus/info.

## Type
- [ ] Inter for display/body, JetBrains Mono for code/labels/eyebrows.
- [ ] Display uses fw-extra(800) + tracking-tight.
- [ ] Commands, agent names, file paths, commit lines rendered in mono.
- [ ] Section labels use `.ns-eyebrow` (mono, uppercase, terracotta, 0.16em).
- [ ] Sizes from the scale tokens; headings sentence case.

## Surface & depth
- [ ] Every card/raised surface has a 1px hairline border (`--border-*`).
- [ ] Shadows from `--elev-*`; never shadow-without-hairline on dark.
- [ ] Radius from scale: buttons `--radius-md`, cards `--radius-lg`, badges `--radius-pill`.
- [ ] Featured/active elements use `--glow-accent`; focus uses `--glow-focus` (present, never removed).

## Motion
- [ ] Transitions use `--ease-out` at `--dur-fast/base/slow`.
- [ ] Button hover `translateY(-1px)`, card hover `-2px`.
- [ ] Only "alive" motion is the streaming terminal. No bounce/parallax/decorative loops.

## Brand & voice
- [ ] `nightshift` is lowercase everywhere.
- [ ] No hype adjectives ("powerful/revolutionary"); proof + numbers instead.
- [ ] "you" for reader, "the agents" for product.
- [ ] Emoji not in body UI; 🌙 / SVG moon mark only as brand glyph.
- [ ] Copy follows thesis → mechanism → proof.

## Structure & assets
- [ ] Uses DS components where they exist; hand-built blocks follow `references/patterns.md`.
- [ ] `NavBar` `logoSrc` / `Footer` `logoSrc` point to `assets/logomark.svg` (correct relative path).
- [ ] Real icons = Lucide; flow markers = Unicode glyphs.
- [ ] Static mock links `styles.css` (or inlines tokens + Google Fonts import).
- [ ] Hero has moon-glow + starfield behind it (if a hero exists).

## Accessibility
- [ ] 🤖 Text/background pairings meet WCAG AA (load-bearing token pairings proven by `check:contrast`; keep the pairings).
- [ ] Focus ring visible on all interactive elements.
