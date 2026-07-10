# @nightshift-ai/marketing

Next.js 16 (App Router) marketing site with an embedded Payload CMS 3 admin.
Site routes live in `src/app/(frontend)/`; the Payload admin/API lives in
`src/app/(payload)/` (generated — don't hand-edit).

## Local development

```bash
pnpm nx run @nightshift-ai/marketing:local-start   # docker compose Postgres
pnpm nx dev @nightshift-ai/marketing
pnpm nx run @nightshift-ai/marketing:local-stop    # when done
```

Configure `DATABASE_URL` / `PAYLOAD_SECRET` in `apps/marketing/.env` (see
`.env.example`).

## Notes

- `@payloadcms/db-postgres` auto-pushes schema changes in development only.
  There is no migrations workflow yet — run the app once in dev mode against a
  fresh database to create the tables.
- Collections: `users` (admin auth, API keys enabled) and `media` (uploads).
