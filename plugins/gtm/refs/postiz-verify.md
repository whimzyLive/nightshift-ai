# Postiz Reachability/Auth Gate Protocol

Used by `/gtm:init` Step 2 (and any future gtm command that needs to confirm Postiz is usable
before proceeding). Runs entirely **through the `postiz` skill/CLI** — gtm never hand-rolls HTTP
against Postiz. Two conditions, **both required to pass**; either failure = **STOP, write
nothing**.

## Condition 1 — Env vars present

The `postiz` CLI requires two environment variables, both set and non-empty:

| Env var | Purpose | Default name |
| ------- | ------- | ------------- |
| `POSTIZ_API_URL` | Postiz backend URL (cloud or self-hosted) | `POSTIZ_API_URL` |
| `POSTIZ_API_KEY` | API key for authentication | `POSTIZ_API_KEY` |

```bash
MISSING=""
[ -z "${POSTIZ_API_URL:-}" ]  && MISSING="$MISSING POSTIZ_API_URL"
[ -z "${POSTIZ_API_KEY:-}" ] && MISSING="$MISSING POSTIZ_API_KEY"
echo "MISSING=${MISSING:-none}"
```

If `MISSING` is not `none`, **STOP** — name the exact missing variable(s):

> Postiz is not configured: environment variable(s) `$MISSING` are not set. Set them in your shell
> (or `.env`, sourced before this session) and re-run `/gtm:init`. No files were written.

Substitute the actual `$MISSING` value computed above (e.g. `POSTIZ_API_URL POSTIZ_API_KEY`) —
do not print the literal string `$MISSING`.

Do **not** proceed to Condition 2 when any env var is missing.

## Condition 2 — Auth probe

Only when Condition 1 passes, probe authentication via the CLI (never raw HTTP):

```bash
postiz auth:status
```

Interpret the result:

- **Authenticated** → gate passes, continue to Step 3.
- **Not authenticated** (bad, expired, or absent key) → **STOP**:

  > Postiz authentication failed: `postiz auth:status` reports not authenticated. Verify
  > `POSTIZ_API_KEY` is a valid, non-expired API key for the backend at `POSTIZ_API_URL`, then
  > re-run `/gtm:init`. No files were written.

- **CLI/connection error** (backend unreachable, DNS failure, timeout, non-zero exit for a reason
  other than "not authenticated") → **STOP**:

  > Postiz backend unreachable: could not reach `POSTIZ_API_URL` via the `postiz` CLI. Confirm the
  > URL is correct and the backend is running/reachable from this machine, then re-run
  > `/gtm:init`. No files were written.

## Secret hygiene

Values are read from the environment at run time and **never persisted**. Only the env-var
**names** (`POSTIZ_API_URL`, `POSTIZ_API_KEY`) are written to `marketing-context.md` — the actual
URL and key values must never appear in any file this plugin writes.

## Re-run behaviour

Both the "Merge" and "Re-run" paths of `/gtm:init`'s re-init guard **re-enter at this gate** before
any write — a dead or unreachable backend can never be re-written against, first run or re-run.
