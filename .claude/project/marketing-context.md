# Marketing Context

| Token        | Value                                             |
| ------------ | ------------------------------------------------- |
| Product name | nightshift                                        |
| One-liner    | Your AI software team that ships while you sleep. |
| Repo         | whimzyLive/nightshift-ai                          |
| Landing URL  | https://github.com/whimzyLive/nightshift-ai       |

Canonical product-marketing detail: see [`.agents/product-marketing.md`](../../.agents/product-marketing.md)
(created and maintained by the marketingskills `product-marketing` skill).

## Postiz

| Token           | Value                     |
| --------------- | ------------------------- |
| Backend URL     | http://localhost:4007/api |
| API key env var | POSTIZ_API_KEY            |

**Secret hygiene:** the **Backend URL** is a non-secret config value, persisted by design — the
`postiz` CLI reads it from the `POSTIZ_API_URL` environment variable at run time, so any command
invoking the CLI must `export POSTIZ_API_URL="<Backend URL>"` from this token first. Only the
env-var **name** for the API key is persisted above; the actual key **value** lives in the
environment and is never written to this file or any other file `/gtm:init` writes.

## Channels

| Channel | Name        | Integration ID            | Ownership | Voice   | Cadence | Content types                              |
| ------- | ----------- | ------------------------- | --------- | ------- | ------- | ------------------------------------------ |
| devto   | Rushi Patel | cmrc8fc340003o57rwrbk9mb4 | auto      | brand   | default | release-note, article-link, tip            |
| x       | Rushi Patel | cmrc60gmz0001o57reda64cvn | draft     | founder | default | release-note, milestone, thread, demo-clip |

## Voice
