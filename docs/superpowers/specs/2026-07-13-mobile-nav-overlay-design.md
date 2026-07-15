# Mobile nav overlay — design

**Date:** 2026-07-13
**Component:** `packages/ui/src/lib/nightshift/nav-bar.tsx`
**Problem:** On mobile the marketing `NavBar` overflows — the four nav links and
both CTAs run off the right edge (visible as a cut-off "The…" and no visible
Install/GitHub buttons). Every other marketing surface is already responsive;
only the nav is not.

## Goal

Below `lg` (1024px), collapse the bar to a **hamburger** that opens a
**full-screen overlay menu** in the nightshift look-and-feel. At `≥ lg` the bar
is unchanged.

## Behavior

- **`≥ lg`:** current bar exactly as-is (logo + 4 links + GitHub + Install).
- **`< lg`:** bar shows **logo left + hamburger button right** only. The inline
  nav links and the two CTAs are hidden (`hidden lg:flex` / `lg:inline-flex`).
- **Open overlay** (`fixed inset-0 z-[60]`, night-sky bg `var(--bg-page)`):
  - Top row: `Logomark` + wordmark left, **✕ Close** button right.
  - Big vertical link list (sans, ~`text-3xl`); active route in `--accent`,
    others `--text-strong`, hover to accent.
  - Bottom: `GitHub` star icon-link + `Install the plugin` CtaButton.
- Overlay is only mounted `< lg` (`lg:hidden`) so the desktop DOM is untouched.

## Interaction / a11y

- Local `useState(open)`.
- Close via: **✕ Close**, **Esc**, **route change** (`usePathname` effect), and
  clicking any overlay link.
- **Body scroll lock** while open (`overflow: hidden` on `document.body`,
  restored on close/unmount).
- **Focus management:** move focus into the overlay on open, return it to the
  hamburger on close. `role="dialog"`, `aria-modal="true"`. Hamburger carries
  `aria-expanded` + `aria-controls`, `aria-label="Open menu"` / Close carries
  `aria-label="Close menu"`.

## Animation

- Motion (`motion` is already a `packages/ui` dependency).
- `AnimatePresence` wraps the overlay: fade + subtle slide/scale in (~200ms);
  links stagger. `prefers-reduced-motion` → instant (matches the existing
  `motion-reduce:transition-none` pattern used across the kit).

## Style

Reuse existing tokens and components only — no new design tokens, no social
icons (nightshift has none): `--bg-page`, `--text-strong`, `--text-muted`,
`--accent`, `--moon-100`, `--glass-border`; reuse `CtaButton`, `Logomark`, and
the existing `GitHubMark` svg. `NAV_LINKS` stays the single source of truth for
both the desktop bar and the overlay.

## Tests (`nav-bar.spec.tsx`, extend)

- Existing `isActiveLink` + desktop-bar assertions keep passing unchanged.
- Hamburger button renders with `aria-expanded="false"`.
- Clicking it opens the overlay (`role="dialog"`) exposing the 4 links +
  GitHub + Install; `aria-expanded="true"`.
- Esc and the Close button both close the overlay.
- Overlay link click closes the overlay.

## Out of scope

- No change to `Footer`, page layouts, or desktop bar markup/behavior.
- No new routes or link targets.
