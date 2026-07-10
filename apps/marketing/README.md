# @nightshift-ai/marketing

Next.js 16 (App Router) marketing site with an embedded Payload CMS 3 admin.
Site routes live in `src/app/(marketing)/`; the Payload admin/API lives in
`src/app/(payload)/` (generated — don't hand-edit).

## Local development

```bash
pnpm nx run @nightshift-ai/marketing:local-start   # docker compose Postgres
pnpm nx dev @nightshift-ai/marketing
pnpm nx run @nightshift-ai/marketing:local-stop     # when done
```

Configure `DATABASE_URL` / `PAYLOAD_SECRET` in `apps/marketing/.env` (see
`.env.example`).

## Deploy prerequisite: Postgres schema

`payload.config.ts` uses `@payloadcms/db-postgres`, which auto-pushes schema
changes in **development only**. This repo has no migrations yet — there is
no `payload migrate` step wired into any build or deploy pipeline.

This matters because the homepage queries the `hero` global
(`src/lib/get-hero-content.ts`) at request time (`export const dynamic =
'force-dynamic'` — see `src/app/(marketing)/page.tsx`). If you deploy to an
environment whose Postgres database doesn't yet have the `hero` table (or
any other collection/global added since the last schema sync), that query
fails. `get-hero-content.ts` catches this and falls back to the same field
defaults defined in `src/lib/hero-defaults.ts`, so **the homepage degrades
gracefully instead of 500ing** — but the CMS-edited content won't be live
until the schema exists.

Before pointing a new environment's `DATABASE_URL` at a fresh Postgres
instance, sync the schema by one of:

- Running the app once against that database with `NODE_ENV=development`
  (Payload's dev-mode auto-push creates any missing tables), or
- Manually applying the schema (`payload migrate` once a real migrations
  workflow exists — out of scope for now, tracked separately).

Building full migrations infrastructure (versioned migrations, CI-run
`payload migrate`) is intentionally out of scope here — this note exists so
the gap is a documented, deliberate choice rather than a deploy-day surprise.
