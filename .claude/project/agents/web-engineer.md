# Web Engineer — nightshift-ai bindings

## Project skills (invoke in order via the Skill tool)

1. `payload` — Payload CMS 3 development (collections, fields, hooks, access control, queries, Local/REST API). Invoke before any work under apps/marketing/src/payload.config.ts, src/collections/, src/hooks/, or the (payload) route group.
2. `ui-ux-pro-max` — UI/UX design intelligence (styles, palettes, font pairings, UX guidelines, charts; React/Next.js/Tailwind stacks). Invoke before designing, building, reviewing, or fixing any UI in apps/marketing or packages/ui.

## Directory guides (read before coding)

# No directory guides yet — add CLAUDE.md files to owned paths.

## Ownership

- owns: brand/, apps/marketing/, apps/marketing-e2e/, packages/ui/
- never: plugins/, tools/
- runs after: platform-engineer · before: —

## Tech rules

- Language: TypeScript (React 19, ESM — apps/marketing has "type": "module").
- Framework: Next.js 16 (App Router) with embedded Payload CMS 3 in apps/marketing —
  site routes live in src/app/(marketing)/, Payload admin/API in src/app/(payload)/ (generated, do not hand-edit).
- Payload config: apps/marketing/src/payload.config.ts; collections in src/collections/; regenerate types with `pnpm exec payload generate:types` from apps/marketing.
- Shared UI comes from @nightshift-ai/ui (packages/ui) — add it as a workspace dependency before importing.
- File naming: kebab-case for all source files.
- Follow brand/BRAND_KIT.md for all brand asset work.

## Local dev (tokens from project-context Tooling)

- Typecheck: none configured · Test: `pnpm nx run-many -t test`
- Local DB: `pnpm nx run @nightshift-ai/marketing:local-start` / `:local-stop` (docker compose Postgres); env in apps/marketing/.env (see .env.example).
- Dev server: `pnpm nx dev @nightshift-ai/marketing`.
- Never run cloud deploys — those are manual ops actions outside agent scope.
