# Channel Configuration Picker Protocol

Used by `/gtm:init` Step 4b — the per-channel ownership/voice/cadence/content-types picker. Runs
entirely **through the `postiz` skill/CLI** — gtm never hand-rolls HTTP against Postiz. This step
only **gathers values into an in-memory Channels model**; it writes nothing to any final path
(`/gtm:init` Step 5 renders the model into `marketing-context.md`).

## Enumeration

Enumerate connected channels via the CLI, with `POSTIZ_API_URL` already exported (Step 2 of
`/gtm:init`):

```bash
postiz integrations:list
```

Capture the full stdout rather than piping it bare into `jq` — most examples (including the
`postiz` skill docs) model piping the command straight to `jq`, but the CLI's actual output may
include a human-readable preamble line before the JSON array (unverified across CLI versions), and
a bare pipe would break on that. Extract the JSON array defensively: take the output starting from
the first line beginning with `[`, then parse that as JSON:

```bash
postiz integrations:list | sed -n '/^\[/,$p' | jq -c '.[] | {id, name, identifier}'
```

Parse `id`, `name`, and `identifier` per element:

- `identifier` — the platform key (e.g. `x`, `linkedin`, `reddit`, `bluesky`, `mastodon`); stable
  across re-runs unless the account is reconnected.
- `name` — the human account/display name; disambiguates two accounts on the same platform.
- `id` — the Postiz integration id, the handle downstream `postiz posts:create -i <id>` requires;
  it can change if a channel is disconnected and re-linked.

Hacker News and Product Hunt are **not** Postiz integrations — they never appear in
`integrations:list` and are out of scope for this picker.

## Per-channel prompt set

For **each** enumerated channel, prompt the founder one channel at a time for the four settings
(AC-2), each pre-seeded with the existing value (re-run) or the schema default (fresh run). Merge
path: only genuinely new channels — plus any the founder asked to adjust (see the Merge-path
adjustment hook under Re-run matching) — are prompted; matched channels otherwise keep their
preserved settings.

- **Ownership** — single-select `auto` / `draft` / `manual`. Default `draft` (AC-4). The `reddit`
  identifier is pre-selected to `manual` as a **recommended** default (subreddit norms punish
  brand-account automation) — the founder may override it. Boundary: when the `reddit` channel
  **is** prompted, `manual` is the pre-selected/default answer, so accepting the default records
  `manual`; a channel that is **never** prompted/answered at all (the founder skips the channel
  entirely) records the AC-4 fallback `draft` instead.
- **Voice** — single-select `brand` / `founder`. Default `brand`.
- **Cadence** — single-select `default` / `daily` / `weekly` / `paused`. Default `default`.
  `default` means inherit the global pulse cadence (~3 posts/week, weekends quiet); `paused` means
  prepared but never scheduled.
- **Content types** — multi-select from the six-value catalogue (below). Default
  `release-note, milestone`.

This step gathers values into an in-memory model only — it writes nothing to final paths; Step 5
of `/gtm:init` renders the model.

## Locked enums + defaults

| Setting | Enum | Default |
| ------- | ---- | ------- |
| Ownership | `auto` \| `draft` \| `manual` | `draft` |
| Voice | `brand` \| `founder` | `brand` |
| Cadence | `default` \| `daily` \| `weekly` \| `paused` | `default` |
| Content types | subset of `release-note`, `tip`, `thread`, `article-link`, `demo-clip`, `milestone` | `release-note, milestone` |

## Empty-list handling

- **Empty `integrations:list` on a fresh run, or a re-entry with no previously configured rows** —
  not an error. Record the empty-table form (header + separator rows only) plus a one-line note
  that channels can be connected in Postiz and picked up on the next `/gtm:init` run into the
  in-memory Channels model; this step still writes nothing to any final path — Step 5 renders it.
  Continue.
- **Empty `integrations:list` on a re-entry that has previously configured rows** — never an
  automatic empty-table write. Apply the drop-confirmation guard below instead.

## Re-run matching (AC-5)

Match existing Channels rows to freshly enumerated channels by **`Integration ID` first**, falling
back to the **(`Channel` identifier, `Name`) pair** when no `Integration ID` match is found (e.g. a
reconnected channel whose stored id has gone stale).

- **Matched row** — preserve `Ownership` / `Voice` / `Cadence` / `Content types` as-is (offer them
  as the pre-selected defaults if re-prompting); refresh both `Integration ID` **and** `Name` from
  the live enumeration on every matched row. `Name` is display data, not a founder setting — it
  must stay current so a later account rename doesn't leave a stale `Name` that breaks the
  (`Channel`, `Name`) fallback match key on a subsequent reconnect. This deliberately supersedes the
  merged spec's "only the `Integration ID` is refreshed" wording.
- **Newly discovered channel** — no matching row → schema defaults apply (`Ownership = draft`,
  AC-4).
- **Merge-path adjustment hook** — on the Merge path (`/gtm:init` Step 0), after prompting for
  genuinely new channels, ask one lightweight follow-up: "Adjust settings for any existing
  channel? (default: no)". If yes, the founder names which matched channel(s) to re-prompt
  (existing values pre-selected as defaults); all other matched rows keep their preserved settings
  untouched. This is what makes graduating a channel from `draft` to `auto` reachable via the
  Merge path, not only via a full Re-run.
- **Previously configured channel no longer returned by `integrations:list`** — list the affected
  channel(s). For **each** one, the founder chooses per-channel: **drop** it from the rewritten
  table, or **retain** it as-is. A retained row is kept unchanged and flagged "stale (not returned
  by Postiz)" in the Step 6 summary. The run continues and writes normally either way — this is a
  per-channel choice, not an all-or-nothing gate. Only a founder's **explicit full-run abort**
  (distinct from a per-channel drop/retain answer) **STOP**s the whole run with the existing rows
  intact and nothing written.
- **Two accounts sharing a platform `identifier`** — disambiguate by `Name`; match/preserve per
  (`identifier`, `Name`).

No setting is ever silently overwritten or dropped (AC-5).

## Error handling

| Scenario | Behaviour |
| -------- | --------- |
| `postiz integrations:list` errors (transport/connection failure, non-zero exit) after Step 2 auth passed | **STOP**: "could not enumerate Postiz channels via `postiz integrations:list`; confirm the backend is reachable and re-run `/gtm:init`." This run writes no `marketing-context.md` changes (Step 5 never runs); note that Step 4 may already have refreshed `.agents/product-marketing.md` — re-run `/gtm:init` to bring `marketing-context.md` back in sync. |
| `postiz integrations:list` exits **zero** but no JSON array can be extracted from its output (see Enumeration) | **STOP** with a distinct parse-error message — never misreport this as backend-unreachable: "`postiz integrations:list` exited successfully but no JSON array could be extracted from its output; confirm the installed `postiz` CLI version matches what this plugin expects (`postiz --version`) and re-run `/gtm:init`." Same write-nothing scope as the row above. |
| An enumerated channel is missing `id`, `name`, or `identifier` | Skip that malformed entry, warn which channel was skipped, continue with the rest. |
| Founder skips / declines to set a channel's ownership | Apply the AC-4 default `draft` — never left blank. |
| Re-run: an existing configured channel no longer returned by `integrations:list` | Per-channel drop-or-retain choice with the founder (see Re-run matching — never silent, never all-or-nothing); the run continues and writes normally either way. Full-run STOP only on an explicit founder abort. |
| Re-run: two accounts share a platform `identifier` | Disambiguate rows by `Name`; match/preserve per (`identifier`, `Name`). |

## Example Channels table row shape

```markdown
| Channel  | Name              | Integration ID | Ownership | Voice   | Cadence | Content types              |
| -------- | ----------------- | -------------- | --------- | ------- | ------- | -------------------------- |
| x        | Nightshift        | <id>           | draft     | brand   | default | release-note, milestone    |
| linkedin | Rishi Patel       | <id>           | draft     | founder | weekly  | release-note, article-link |
| reddit   | u/nightshift-bot  | <id>           | manual    | founder | paused  | article-link               |
```

`<id>` above is the illustrative Postiz `id` value for that row — the written file materializes the
real `integrations:list` id, never a literal placeholder token.
