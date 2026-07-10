# Migrations — deploy notes

`20260710_104756_na22_globals` is the **schema baseline** for this app — it's a
full init migration that creates every table (`media`, `users`, `payload_*`,
the `home` / `site_settings` / `why_sdlc` globals and their array/block
sub-tables), not an incremental change. Payload generated it as the first
migration because no `payload_migrations` row existed yet when it ran.

## Deploying to an environment already provisioned by Payload dev push-mode

Local dev (`payload dev` / `next dev`) uses Payload's schema **push** mode,
which creates/updates tables directly without recording migration rows. If
you point this migration at an environment whose schema was provisioned that
way (tables already exist), **do not run it** — `up()` will fail trying to
`CREATE TABLE` on existing tables. Instead, mark it as already applied
(baseline it) so future migrations run from this point forward:

```bash
pnpm --filter @nightshift-ai/marketing exec payload migrate:status
# if the baseline migration isn't recorded, insert its row directly, e.g.:
pnpm --filter @nightshift-ai/marketing exec payload migrate --skip-ahead
```

(`migrate --skip-ahead`, or an equivalent manual `payload_migrations` insert,
records the migration as run without executing `up()` — check
`payload migrate --help` for the exact flag in the installed Payload
version.) On a genuinely fresh database (no tables), run the migration
normally: `pnpm --filter @nightshift-ai/marketing exec payload migrate`.

## `down()` is destructive

`down()` drops `users`, `media`, and every other table this migration
created — running it against an environment with real data (accounts,
uploaded media) deletes that data irrecoverably. Never run `payload
migrate:down` against a populated environment.
