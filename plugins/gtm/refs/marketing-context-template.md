# Marketing Context Template

Canonical template for `.claude/project/marketing-context.md` — the gtm counterpart to sdlc's
`project-context.md`. `/gtm:init` Step 5 fills this template from the collected/detected values;
no placeholder tokens (`<...>`) may remain in the generated file. Distinct from
`.agents/product-marketing.md`, which the marketingskills `product-marketing` skill owns — this
file holds gtm's own operational config and points at that file as the canonical product-marketing
detail.

## Template

```markdown
# Marketing Context

| Token       | Value            |
| ----------- | ---------------- |
| Product name | <name> |
| One-liner    | <one-liner> |
| Repo         | <repo> |
| Landing URL  | <landing URL, or blank> |

Canonical product-marketing detail: see [`.agents/product-marketing.md`](../../.agents/product-marketing.md)
(created and maintained by the marketingskills `product-marketing` skill).

## Postiz

| Token             | Value              |
| ----------------- | ------------------ |
| Backend URL       | <resolved Postiz backend URL — cloud default `https://api.postiz.com` or a self-hosted URL, chosen at init> |
| API key env var   | <API key env var, default `POSTIZ_API_KEY`> |

**Secret hygiene:** the **Backend URL** is a non-secret config value, persisted by design — the
`postiz` CLI reads it from the `POSTIZ_API_URL` environment variable at run time, so any command
invoking the CLI must `export POSTIZ_API_URL="<Backend URL>"` from this token first. Only the
env-var **name** for the API key is persisted above; the actual key **value** lives in the
environment and is never written to this file or any other file `/gtm:init` writes.

## Channels

| Channel | Name | Integration ID | Ownership | Voice | Cadence | Content types |
| ------- | ---- | --------------- | --------- | ----- | ------- | ------------- |

## Voice

<voice overrides — markdown block, empty at init; populated by a downstream story>
```

**Example rows (illustrative only — never render these into a generated file):** a materialised
`## Channels` table looks like this once real channels are configured:

| Channel  | Name              | Integration ID | Ownership | Voice   | Cadence | Content types              |
| -------- | ----------------- | -------------- | --------- | ------- | ------- | -------------------------- |
| x        | Nightshift        | <id>           | draft     | brand   | default | release-note, milestone    |
| linkedin | Rishi Patel       | <id>           | draft     | founder | weekly  | release-note, article-link |
| reddit   | u/nightshift-bot  | <id>           | manual    | founder | paused  | article-link               |

## Schema

**Content-type catalogue (locked, six values):** `release-note` (shipped feature / merged PR /
changelog highlight) · `tip` (usage tip / how-to) · `thread` (long-form multi-part narrative) ·
`article-link` (link to a cross-posted long-form article) · `demo-clip` (the VHS + Remotion demo
video) · `milestone` (KPI / community milestone, e.g. star count).

| Section | Field | Type | Required | Default | Notes |
| ------- | ----- | ---- | -------- | ------- | ----- |
| Product | `name` | string | Yes | — | Detected or interviewed |
| Product | `one-liner` | string | Yes | — | Tagline / one-sentence pitch |
| Product | `repo` | string (URL or `owner/name`) | Yes | — | From `git remote` or interview |
| Product | `landing URL` | string (URL) | No | empty | Blank allowed if none exists yet |
| Postiz  | `Backend URL` | string (URL) | Yes | `https://api.postiz.com` | Postiz backend URL — cloud default or self-hosted, chosen at init via AskUserQuestion (seeded from `POSTIZ_API_URL` env if already set). Not a secret — persisted by design; exported as `POSTIZ_API_URL` by any command invoking the `postiz` CLI. |
| Postiz  | `API key env var` | string (env var name) | Yes | `POSTIZ_API_KEY` | Name only — never the value |
| Channels | `Channel` | string | Yes | — | Postiz `identifier` — platform key from `integrations:list`. |
| Channels | `Name` | string | Yes | — | Postiz `name` — account display name; disambiguates multiple accounts on one platform. |
| Channels | `Integration ID` | string | Yes | — | Postiz `id`, refreshed every run; downstream publish handle; primary re-run match key but not stable identity (reconnect can go stale — `(Channel, Name)` fallback applies). |
| Channels | `Ownership` | enum `auto` \| `draft` \| `manual` | Yes | `draft` | AC-4: any channel not explicitly set is `draft`. |
| Channels | `Voice` | enum `brand` \| `founder` | Yes | `brand` | `brand` = product/brand account voice; `founder` = founder's personal voice; distinct from the global Voice overrides section below. |
| Channels | `Cadence` | enum `default` \| `daily` \| `weekly` \| `paused` | Yes | `default` | `default` = inherit global pulse cadence; `paused` = prepared but never scheduled. |
| Channels | `Content types` | comma-separated subset of the six-value catalogue | Yes | `release-note, milestone` | Multi-select. |
| Voice   | `voice overrides` | markdown block | No | empty | ECC anti-slop overrides, populated by a downstream story |

## Fill rules

1. Every token slot (`<...>`) is replaced with an actual value from Step 3 detection or the
   founder's interview answers — no placeholder may remain in the written file.
2. `landing URL` may be written blank (empty table cell) when no source resolved and the founder
   declined to supply one.
3. `Backend URL` is chosen at init: cloud default (`https://api.postiz.com`) or a self-hosted URL
   the founder supplies — never left blank. `API key env var` defaults to `POSTIZ_API_KEY`; only
   override the name if the founder explicitly names a different variable for their setup.
4. `Voice` starts empty — a downstream story (voice overrides / content strategy) populates it.
   Never invent voice guidance at init time.
5. On the "Merge new findings" re-init path, preserve every value already set; only backfill
   template fields that are absent from the existing file.
6. Materialise every Channels row fully — no `<...>` placeholder token may remain (`Integration ID`
   filled from the live `integrations:list` `id`).
7. When `integrations:list` returns zero channels, write the empty-table form (header + separator
   rows only) plus the one-line "connect channels in Postiz and re-run" note. Exception: on a
   re-entry that already has configured rows, an empty enumeration triggers the drop-confirmation
   guard (see `${CLAUDE_PLUGIN_ROOT}/refs/channel-config.md` Re-run matching) rather than an
   automatic empty-table write.
8. Per-channel `Voice` column is distinct from the global `## Voice` overrides section — the latter
   stays empty at init.
9. On the Merge/Re-run path, preserve every existing channel setting; only backfill
   channels/settings absent from the file; refresh `Integration ID` every run (per
   `${CLAUDE_PLUGIN_ROOT}/refs/channel-config.md` re-run matching).
