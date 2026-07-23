---
title: Postiz setup for gtm
description: Connect the gtm plugin to a running Postiz instance so channels can be configured and content published.
source:
  - plugins/gtm/commands/init.md
related-adrs: []
---

# Postiz setup for gtm

Wire the gtm plugin to a Postiz backend so `/gtm:init` can enumerate your channels and downstream
commands can publish. gtm never talks HTTP to Postiz directly — every Postiz call goes through the
`postiz` CLI, which reads its backend URL and API key from environment variables.

## Prerequisites

- A running Postiz backend, reachable at its Backend URL (e.g. `http://localhost:4007/api` for a
  local instance, or `https://api.postiz.com` for the cloud default).
- A Postiz API key for that backend.
- The `postiz@postiz-agent` plugin installed. `/gtm:init` installs it for you if missing; nothing
  below requires installing it by hand first.
- One or more social channels already connected inside Postiz. gtm reads the integrations Postiz
  exposes; it does not create them.

## Export the connection environment variables

The `postiz` CLI reads the backend URL from `POSTIZ_API_URL` and the API key from `POSTIZ_API_KEY`.
Export both before running `/gtm:init`:

```bash
export POSTIZ_API_URL="http://localhost:4007/api"
export POSTIZ_API_KEY="<your-postiz-api-key>"
```

`POSTIZ_API_URL` only seeds the default answer to the Backend URL question `/gtm:init` asks — it
does not skip the question. `POSTIZ_API_KEY` must be set and non-empty for the gate to pass.

### Security note: never write the API key value to a file

The API key is a secret and must live only in your environment. Export it as `POSTIZ_API_KEY` in
your shell or an untracked `.env` file, and keep it there. `/gtm:init` persists only the _name_ of
the environment variable (`POSTIZ_API_KEY`) into `marketing-context.md` — never the key's value.
Do not paste the key into `marketing-context.md`, into any committed config, or into a command that
another tool records. If you rotate the key, update the environment variable; nothing on disk needs
to change, because nothing on disk ever held the value.

The Backend URL is treated differently: it is a configuration token, not a secret, so `/gtm:init`
does persist it to `marketing-context.md`. After init, that stored token is authoritative — later
changes to `POSTIZ_API_URL` have no effect unless you re-run `/gtm:init`.

## Run the reachability gate

`/gtm:init` gates on Postiz reachability before it writes any config. The gate has three conditions,
all required, and it runs on every invocation — first run and re-run alike — so a dead or
unreachable backend can never be written against:

1. Resolve the Backend URL. On a fresh run you pick **Cloud default** (`https://api.postiz.com`) or
   **Self-hosted** (you supply the URL); a set `POSTIZ_API_URL` seeds the default. `/gtm:init`
   exports the resolved value for the rest of the session.
2. `POSTIZ_API_KEY` is set and non-empty.
3. `postiz auth:status` (with the resolved `POSTIZ_API_URL` exported) reports authenticated.

If any condition fails — unresolved Backend URL, missing `POSTIZ_API_KEY`, a not-authenticated
result, or a CLI/connection error — `/gtm:init` stops with the matching message and writes nothing.
Fix the reported condition and re-run.

Run it:

```bash
/gtm:init
```

## Configure each channel

Once the gate passes, `/gtm:init` reads each channel's integration `id`, `name`, and `identifier`
from `postiz integrations:list` — you do not enter the integration ID; it is recorded for you. It
then walks your channels one at a time and prompts you for four settings. Answer each per channel:

1. **Ownership** — `auto` (gtm may publish to this channel without a human gate) or `draft` (gtm
   prepares content but never publishes unattended). A channel you skip falls back to `draft`; the
   `reddit` identifier defaults to `manual`.
2. **Voice** — the tone override for this channel, or blank to inherit the product voice.
3. **Cadence** — how often gtm should post to this channel.
4. **Content types** — the kinds of content this channel accepts.

All answers land in the `## Channels` table of `.claude/project/marketing-context.md`. To graduate a
channel from `draft` to `auto` later, re-run `/gtm:init` and change its ownership (Merge or Re-run
both reach the per-channel prompts).

## Verify the connection

Confirm the backend is reachable and authenticated with a direct reachability probe — the same check
the gate runs:

```bash
postiz auth:status
```

An authenticated result means the connection gtm depends on is live. Then confirm your channels
enumerate:

```bash
postiz integrations:list
```

Each row here is a channel `/gtm:init` will offer to configure. After a successful `/gtm:init`, the
`## Channels` table in `.claude/project/marketing-context.md` should list every channel you
configured, with its ownership, voice, cadence, and content types filled in.

## Next steps

- New to the plugin? See the tutorial: [docs/tutorials/getting-started-with-gtm.md](../tutorials/getting-started-with-gtm.md).
- Want the reasoning behind gtm's design and the Postiz split? See
  [docs/concepts/what-is-the-gtm-plugin.md](../concepts/what-is-the-gtm-plugin.md).
