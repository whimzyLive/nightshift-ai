# Postiz Reachability/Auth Gate Protocol

Used by `/gtm:init` Step 2 (and any future gtm command that needs to confirm Postiz is usable
before proceeding). Runs entirely **through the `postiz` skill/CLI** — gtm never hand-rolls HTTP
against Postiz. Three conditions, **all required to pass**; any failure = **STOP, write nothing**.

## Condition 1 — Resolve the backend URL

The `postiz` CLI reads its backend URL from the `POSTIZ_API_URL` environment variable at run time.
gtm treats the backend URL as a **persisted, non-secret config value** in
`.claude/project/marketing-context.md` (Postiz → `Backend URL`), not an env-only secret. Resolve it
in this order, first match wins:

1. **Existing marketing-context token** — if `.claude/project/marketing-context.md` already has a
   Postiz `Backend URL` value (re-init: Merge/Re-run re-entering this gate), use it. Re-run offers
   it as the default answer if re-prompting.
2. **`POSTIZ_API_URL` env var, if set** — seeds the default choice below (does not skip the
   question): if it is unset, no seed is offered.
3. **`AskUserQuestion`** — ask the founder to choose:

   ```
   AskUserQuestion(
     header: "Postiz backend",
     question: "Which Postiz backend should this project use?",
     multiSelect: false,
     options: [
       { label: "Cloud default", description: "Use Postiz's hosted cloud backend: https://api.postiz.com" },
       { label: "Self-hosted",   description: "Supply your own self-hosted Postiz backend URL." }
     ]
   )
   ```

   - **Cloud default** → resolved URL is `https://api.postiz.com`.
   - **Self-hosted** → prompt for the URL (pre-filled with the Step-2 env seed from source 2 above,
     when present); the founder's answer is the resolved URL.

**Precedence after this gate:** the value written to `marketing-context.md` (Step 5) is henceforth
authoritative. An env var seeds the _first_ resolution only — once a Backend URL token exists in
`marketing-context.md`, it wins over whatever `POSTIZ_API_URL` happens to be set to in a later
shell session.

Export the resolved value for the rest of this session so the CLI can read it:

```bash
export POSTIZ_API_URL="<resolved backend URL>"
```

If no URL can be resolved (should not happen — the `AskUserQuestion` step always yields one, unless
skipped in error), **STOP**:

> Postiz backend URL could not be resolved. Re-run `/gtm:init` and answer the backend-URL prompt.
> No files were written.

## Condition 2 — API key env var present

The `postiz` CLI also requires the API-key environment variable, set and non-empty:

| Env var          | Purpose                    | Default name     |
| ---------------- | -------------------------- | ---------------- |
| `POSTIZ_API_KEY` | API key for authentication | `POSTIZ_API_KEY` |

```bash
[ -z "${POSTIZ_API_KEY:-}" ] && echo "MISSING=POSTIZ_API_KEY" || echo "MISSING=none"
```

If `MISSING` is not `none`, **STOP**:

> Postiz is not configured: environment variable `POSTIZ_API_KEY` is not set. Set it in your shell
> (or `.env`, sourced before this session) and re-run `/gtm:init`. No files were written.

Do **not** proceed to Condition 3 when the API key env var is missing.

## Condition 3 — Auth probe

Only when Conditions 1–2 pass (with `POSTIZ_API_URL` exported per Condition 1), probe
authentication via the CLI (never raw HTTP):

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
  > backend URL is correct and the backend is running/reachable from this machine, then re-run
  > `/gtm:init`. No files were written.

## Secret hygiene

The **Backend URL** is not a secret — it is persisted to `marketing-context.md` by design (Condition 1) and exported as `POSTIZ_API_URL` before every CLI invocation. Only the **API key** stays env-only: its **name** (`POSTIZ_API_KEY`) is written to `marketing-context.md`, never its value. The actual key value is read from the environment at run time and never persisted to any file this plugin writes.

## Re-run behaviour

Both the "Merge" and "Re-run" paths of `/gtm:init`'s re-init guard **re-enter at this gate** before
any write — a dead or unreachable backend can never be re-written against, first run or re-run. On
Merge, the existing Backend URL token (Condition 1, source 1) is reused as-is; on Re-run, it is
offered as the default answer if the founder chooses to change it.
