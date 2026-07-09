# Web Engineer — memory

## 2026-07-10 — GTM landing page (docs/gtm/site-brief.md) — implemented on feat/gtm-landing-page
**Learnings:**
- The `nightshift-design` skill ships production-shaped component sources at
  `.claude/skills/nightshift-design/components/**/*.jsx` (+ `.d.ts` for the API) — these
  are throwaway-mock components (inline style objects, `window.NightshiftDesignSystem_983007`
  namespace, `useState` hover tracking) meant for static HTML mocks, not for direct import.
  Port them to real TSX + CSS Modules in `packages/ui/src/lib/nightshift/` (hover via `:hover`
  CSS, not JS state) — keeps them server-renderable and matches the repo's existing CSS
  Modules convention (see old `hero-banner.tsx`).
- Exact recipes for the "starfield" and "moon-glow" decorative motifs (not in the token
  files) live in `references/patterns.md` — copy verbatim as global utility classes
  (`.ns-starfield`, `.ns-moon-glow`, `.ns-eyebrow`) in the consuming app's global.css.
- Font tokens (`--font-sans`/`--font-mono`) in the design system reference literal family
  names ('Inter', 'JetBrains Mono'). For production, self-host via `next/font/google` with
  `variable: '--font-inter'` / `'--font-jetbrains-mono'`, apply the classNames to `<html>`
  in `(marketing)/layout.tsx`, then alias `--font-sans`/`--font-mono` to
  `var(--font-inter)`/`var(--font-jetbrains-mono)` in the tokens CSS — satisfies the design
  system's own "self-host for production" caveat with zero extra dependency.

**Pitfalls:**
- `@testing-library/jest-dom` is **not installed** in this workspace (no `toBeInTheDocument`
  matcher available) and `@testing-library/user-event` isn't either. Write component tests
  with plain `toBeTruthy()` / `fireEvent` from `@testing-library/react` only — do not assume
  jest-dom matchers exist, and don't add either package (lockfile is off-limits).
- A `<button>`'s `aria-label` overrides its visible text for the accessible name computation —
  if a copy-to-clipboard button's label changes on click ("copy" → "copied ✓"), the
  `aria-label` must change too (or be removed) or `getByRole('button', {name: ...})` won't
  find the post-click state in tests.
- `<details>` cannot be a child of `<dl>` (invalid HTML) — use a plain wrapper `<div>` with
  `<details><summary>` + `<p>` for an accessible, zero-JS FAQ accordion instead.

**Patterns:**
- Native `<details>`/`<summary>` gives a zero-JS mobile nav disclosure and FAQ accordion —
  avoids adding a client-side dependency for basic show/hide interaction, keeps Server
  Components RSC-friendly (only the clipboard-copy `InstallSnippet` needs `'use client'`).
- `pnpm nx build @nightshift-ai/marketing` runs a real `tsc` pass via `next build` even
  though the project's declared quality gate is `test`-only — worth running once after
  large changes to catch type errors the Babel-based jest transform won't.
