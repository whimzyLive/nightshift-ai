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

## Voice

<voice overrides — markdown block, empty at init; populated by a downstream story>
```

## Schema

| Section | Field | Type | Required | Default | Notes |
| ------- | ----- | ---- | -------- | ------- | ----- |
| Product | `name` | string | Yes | — | Detected or interviewed |
| Product | `one-liner` | string | Yes | — | Tagline / one-sentence pitch |
| Product | `repo` | string (URL or `owner/name`) | Yes | — | From `git remote` or interview |
| Product | `landing URL` | string (URL) | No | empty | Blank allowed if none exists yet |
| Postiz  | `Backend URL` | string (URL) | Yes | `https://api.postiz.com` | Postiz backend URL — cloud default or self-hosted, chosen at init via AskUserQuestion (seeded from `POSTIZ_API_URL` env if already set). Not a secret — persisted by design; exported as `POSTIZ_API_URL` by any command invoking the `postiz` CLI. |
| Postiz  | `API key env var` | string (env var name) | Yes | `POSTIZ_API_KEY` | Name only — never the value |
| Voice   | `voice overrides` | markdown block | No | empty | ECC anti-slop overrides, populated by a downstream story |

## Fill rules

1. Every token slot (`<...>`) is replaced with an actual value from Step 3 detection or the
   founder's interview answers — no placeholder may remain in the written file.
2. `landing URL` may be written blank (empty table cell) when no source resolved and the founder
   declined to supply one.
3. `Backend URL` is chosen at init: cloud default (`https://api.postiz.com`) or a self-hosted URL
   the founder supplies — never left blank. `API key env var` defaults to `POSTIZ_API_KEY`; only
   override the name if the founder explicitly names a different variable for their setup.
4. `Voice` starts empty — a downstream story (channel ownership/voice/cadence) populates it. Never
   invent voice guidance at init time.
5. On the "Merge new findings" re-init path, preserve every value already set; only backfill
   template fields that are absent from the existing file.
