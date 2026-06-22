# nightshift — complete token catalog

**Rule: never hardcode a value that has a token. Always use the CSS variable.** Raw scale values (`--night-600`) exist; in components use the **semantic alias** (`--surface-card`). Import everything via `styles.css`. Source of truth: `tokens/*.css`.

> ⚠️ **Values below mirror `tokens/colors.css` / `_ds_manifest.json` — they are not a second source of truth.** Don't hand-edit a value out of sync; `npm run check:tokens` fails the build on any drift.

---

## Color

### Raw scale — night-sky background layers (deepest → raised)
| Token | Value | Use |
|-------|-------|-----|
| `--night-900` | `#08080f` | page void — deepest |
| `--night-800` | `#0d0d18` | default page background |
| `--night-700` | `#12121f` | sunken / code well |
| `--night-600` | `#1a1a2e` | primary surface (cards, terminal body) |
| `--night-500` | `#22223a` | raised surface (hover, popovers) |
| `--night-400` | `#2c2c47` | overlay / active surface |

### Hairlines (the separator on dark — shadow alone won't read)
| Token | Value |
|-------|-------|
| `--line-soft` | `rgba(255,255,255,0.06)` |
| `--line` | `rgba(255,255,255,0.10)` |
| `--line-strong` | `rgba(255,255,255,0.16)` |

### Moonlight text
| Token | Value | Use |
|-------|-------|-----|
| `--moon-100` | `#f5f3ef` | primary text — warm off-white |
| `--moon-200` | `#d8d6e0` | secondary / body |
| `--moon-300` | `#a9a7bd` | muted / supporting |
| `--moon-400` | `#74738c` | dim / captions, code comments |
| `--moon-500` | `#4d4c63` | faintest / disabled |

### Terracotta accent — the ONE pointing color (Anthropic-aligned)
| Token | Value | Use |
|-------|-------|-----|
| `--terra-300` | `#f0a488` | |
| `--terra-400` | `#e58b6f` | hover |
| `--terra-500` | `#d97757` | **brand accent** |
| `--terra-600` | `#c2624a` | press |
| `--terra-700` | `#9d4d3a` | |
| `--terra-glow` | `rgba(217,119,87,0.28)` | halo |
| `--terra-tint` | `rgba(217,119,87,0.12)` | tinted fill / selection |

### Cool secondary — moonlit indigo (links, focus, info)
| Token | Value |
|-------|-------|
| `--indigo-300` | `#a5b4fc` |
| `--indigo-400` | `#8b9cf7` |
| `--indigo-500` | `#7c93f0` |
| `--indigo-tint` | `rgba(124,147,240,0.14)` |

### Cyan — data / terminal highlights
| `--cyan-400` | `#62c4d3` | · | `--cyan-500` | `#4fb3c4` |

### Semantic (terminal-true)
| Token | Value | Tint |
|-------|-------|------|
| `--green-400` (success/added/passing) | `#6ec48a` | `--green-tint` `rgba(110,196,138,0.14)` |
| `--amber-400` (warning/pending) | `#e0a458` | `--amber-tint` `rgba(224,164,88,0.14)` |
| `--red-400` (error/removed/failing) | `#e0656f` | `--red-tint` `rgba(224,101,111,0.14)` |

### Semantic aliases — USE THESE in components
```
Backgrounds   --bg-page=night-800  --bg-void=night-900  --bg-sunken=night-700
Surfaces      --surface-card=night-600  --surface-raised=night-500
              --surface-overlay=night-400  --surface-terminal=#0b0b14
Borders       --border-soft  --border-default  --border-strong
              --border-accent=rgba(217,119,87,0.45)
Text          --text-strong=moon-100  --text-body=moon-200  --text-muted=moon-300
              --text-dim=moon-400  --text-disabled=moon-500  --text-on-accent=#1a0f0a
Accent        --accent=terra-500  --accent-hover=terra-400  --accent-press=terra-600
              --accent-tint  --accent-glow
Links/focus   --link=indigo-400  --link-hover=indigo-300  --focus-ring=indigo-500
States        --success=green-400  --warning=amber-400  --danger=red-400  --info=cyan-400
```

### Code-token colors (for syntax in Terminal/CodeBlock)
`--code-comment`=moon-400 · `--code-keyword`=indigo-400 · `--code-string`=green-400 · `--code-fn`=terra-400 · `--code-num`=cyan-400 · `--code-punct`=moon-300 · `--code-prompt`=terra-500

---

## Typography

```
Families   --font-sans  'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif
           --font-mono  'JetBrains Mono', 'SFMono-Regular', ui-monospace, 'Cascadia Code', Menlo, Consolas, monospace
Weights    --fw-regular 400 · --fw-medium 500 · --fw-semibold 600 · --fw-bold 700 · --fw-extra 800
```

### Type scale (tuned major-third)
| Token | px | | Token | px |
|-------|----|-|-------|----|
| `--text-2xs` | 11 | | `--text-xl` | 25 |
| `--text-xs` | 12 | | `--text-2xl` | 32 |
| `--text-sm` | 13 | | `--text-3xl` | 42 |
| `--text-base` | 15 | | `--text-4xl` | 56 |
| `--text-md` | 17 | | `--text-5xl` | 72 |
| `--text-lg` | 20 | | `--text-6xl` | 92 |

```
Leading    --leading-tight 1.06 · --leading-snug 1.22 · --leading-normal 1.5 · --leading-relaxed 1.65
Tracking   --tracking-tight -0.02 · --tracking-snug -0.01 · --tracking-normal 0
           --tracking-wide 0.04 · --tracking-eyebrow 0.16em (mono uppercase labels)
Roles      display: Inter / fw-extra(800) / tracking-tight
           heading: Inter / fw-bold(700) / tracking-snug
           body:    Inter / fw-regular(400) / 15px / leading-normal
           eyebrow: mono  / fw-medium(500) / tracking-eyebrow / UPPERCASE / --accent
           code:    JetBrains Mono
```

Eyebrow utility class ships in `base.css`: **`.ns-eyebrow`** — use it directly for `// SECTION LABEL`.

---

## Spacing / radius / elevation / motion / layout

```
Spacing (4px base)  --space-1=4 -2=8 -3=12 -4=16 -5=20 -6=24 -8=32 -10=40
                    --space-12=48 -16=64 -20=80 -24=96 -32=128
Radius              --radius-xs=4 -sm=6 -md=10(buttons) -lg=14(cards) -xl=20 -2xl=28 -pill=999
Elevation (deep+soft; ALWAYS pair with a hairline)
  --elev-0 none
  --elev-1 0 1px 2px rgba(0,0,0,.4)
  --elev-2 0 4px 16px rgba(0,0,0,.45)
  --elev-3 0 12px 32px rgba(0,0,0,.5)
  --elev-4 0 24px 64px rgba(0,0,0,.55)
Glow ("light in the dark")
  --glow-accent  0 0 0 1px rgba(217,119,87,.35), 0 8px 28px rgba(217,119,87,.22)   primary btn, active stage
  --glow-cool    0 0 0 1px rgba(124,147,240,.35), 0 8px 28px rgba(124,147,240,.18)  cool emphasis
  --glow-focus   0 0 0 3px rgba(124,147,240,.45)                                    focus ring — NEVER remove
Motion   --ease-out cubic-bezier(.22,1,.36,1) · --ease-in-out cubic-bezier(.65,0,.35,1)
         --dur-fast 120ms · --dur-base 200ms · --dur-slow 360ms
Layout   --container-max 1200 · --container-prose 720 · --nav-height 64
```

## Base element behaviors (`base.css`, already applied on `body`)
- `box-sizing:border-box` everywhere.
- `body`: `--bg-page` bg, `--text-body`, Inter, 15px, leading-normal, antialiased.
- Headings: `--text-strong`, bold, snug leading, tracking-snug.
- Links: `--link` → `--link-hover`, no underline, fast color transition.
- `::selection` = `--terra-tint` on `--moon-100`.
- `:focus-visible` = `--glow-focus`, radius-xs, no default outline.
- Nocturnal scrollbar: thin, `--night-400` thumb, pill radius.
