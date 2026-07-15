# Web Engineer — nightshift-ai bindings

## Project skills (invoke in order via the Skill tool)

1. `nightshift-design` — the nightshift design system and brand (night-sky theme, terracotta accent, design tokens incl. the sharp-edge radius override, UI-kit components, brand voice, runnable adherence gate). Invoke FIRST for any visual/UI/copy work in apps/marketing, packages/ui, or brand assets. Its `tokens/*.css` + `_ds_manifest.json` carry the exact values, kept in sync with `docs/design/marketing-site-handoff/` — query the manifest for an exact hex, never guess. Run its `npm run validate` gate before finishing UI work.
2. `payload` — Payload CMS 3 development (collections, fields, hooks, access control, queries, Local/REST API). Invoke before any work under apps/marketing/src/payload.config.ts, src/collections/, src/hooks/, or the (payload) route group.
3. `tailwind-design-system` — Tailwind CSS v4 design systems (design tokens, component libraries, responsive patterns). Invoke when setting up or extending Tailwind, mapping nightshift-design tokens into `@theme`, or standardizing UI patterns in apps/marketing or packages/ui.
4. `vercel-react-best-practices` — React/Next.js performance patterns from Vercel Engineering. Invoke when writing, reviewing, or refactoring React/Next.js code.
5. `vercel-composition-patterns` — React composition patterns (compound components, render props, context providers, React 19 APIs). Invoke when designing reusable component APIs or refactoring boolean-prop proliferation.
6. `atomic-design` — repo-authored atomic design methodology (atoms → molecules → organisms → templates → pages; hierarchy, naming, composition decisions). Invoke when structuring or decomposing UI into reusable components in apps/marketing or packages/ui.
7. `motion-dev-animations` — Motion.dev (Framer Motion successor) React/Next.js animations: entrances, gestures, scroll reveals, layout transitions, spring physics, prefers-reduced-motion. Invoke for React component animations and micro-interactions in apps/marketing.

## Directory guides (read before coding)

# No directory guides yet — add CLAUDE.md files to owned paths.

## Ownership

- owns: brand/, apps/marketing/, apps/marketing-e2e/, packages/ui/
- never: plugins/, tools/
- runs after: platform-engineer · before: —

## Tech rules

- Language: TypeScript (React 19, ESM — apps/marketing has "type": "module").
- UI layer: always .tsx + Tailwind CSS v4 (utility classes in TSX, tokens in `@theme`) — no .jsx, no CSS Modules, no SCSS (sole exception: generated (payload)/custom.scss).
- Framework: Next.js 16 (App Router) with embedded Payload CMS 3 in apps/marketing —
  site routes live in src/app/(frontend)/, Payload admin/API in src/app/(payload)/ (generated, do not hand-edit).
- Payload config: apps/marketing/src/payload.config.ts; collections in src/collections/; regenerate types with `pnpm exec payload generate:types` from apps/marketing.
- Shared UI comes from @nightshift-ai/ui (packages/ui) — add it as a workspace dependency before importing.
- File naming: kebab-case for all source files.
- Follow brand/BRAND_KIT.md for all brand asset work.

## Local dev (tokens from project-context Tooling)

- Typecheck: none configured · Test: `pnpm nx run-many -t test`
- Local DB: `pnpm nx run @nightshift-ai/marketing:local-start` / `:local-stop` (docker compose Postgres); env in apps/marketing/.env (see .env.example).
- Dev server: `pnpm nx dev @nightshift-ai/marketing`.
- Never run cloud deploys — those are manual ops actions outside agent scope.
