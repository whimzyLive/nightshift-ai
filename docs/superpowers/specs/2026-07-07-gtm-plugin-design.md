# GTM Plugin — Design Spec

**Date:** 2026-07-07
**Status:** Approved for planning
**Owner:** nightshift marketplace — new plugin `plugins/gtm`

## Problem

Developer founders ship products that nobody sees. nightshift's `sdlc` plugin automates the build
side (Jira → spec → plan → impl → review → PR); nothing automates the distribution side. nightshift
itself is the first proof case: its growth push (tracked under Epic NA-2, the source of truth for
all nightshift-ai work) needs a landing site, demo, brand kit, launch posts, and a continuous
content stream — with GitHub stars as the primary KPI and agent ownership of every channel that
allows it.

## Solution

A second nightshift plugin, `gtm` — a continuous marketing engine ("marketing while you sleep")
that mirrors the sdlc architecture: agents + commands + refs + per-repo config. It turns shipped
work (git activity) into channel-ready content, publishes through Postiz, tracks the KPI, and
tunes its own calendar. sdlc builds; gtm distributes. Tracked as Epic NA-2.

### Division of labor

| Layer | Provides |
|---|---|
| [marketingskills](https://github.com/coreyhaines31/marketingskills) (cross-marketplace dep) | Expertise: copywriting, cro, launch, ai-seo, content-strategy, directory-submissions, copy-editing, product-marketing |
| `gtm` plugin | Orchestration: agent roles, git-driven loop, state, gates, KPI tracking |
| Postiz (MCP, 9 tools) | Hands: channel discovery (`integrationList`), platform rules (`integrationSchema`), draft/schedule/publish (`schedulePostTool`), AI images + short video (`generateImageTool`, `generateVideoTool`) |
| `sdlc` plugin (optional) | Build handoff for landing site / docs PRs |
| `.claude/project/marketing-context.md` | Per-repo config (same pattern as sdlc's `project-context.md`) |

`/gtm:init` also writes `.agents/product-marketing.md` — marketingskills' expected context file —
so upstream skills work unmodified.

## Plugin layout

```
plugins/gtm/
├── .claude-plugin/plugin.json   # deps: marketingskills; sdlc optional
├── agents/
│   ├── marketing-strategist.md  # positioning, calendar, channel mix
│   ├── content-writer.md        # per-channel drafts + media, obeys integrationSchema
│   └── growth-analyst.md        # KPI + analytics pull, digest, calendar tuning, social-proof harvest
├── commands/
│   ├── init.md      # scaffold config, verify Postiz, channel picker
│   ├── pulse.md     # one engine pass — THE loop body
│   ├── launch.md    # launch campaign (nightshift launch asset list)
│   ├── report.md    # analytics digest + recommendations
│   ├── site.md      # landing page: copy → brand → build handoff
│   └── docs.md      # docs-SEO: audit → doc-improvement PRs
├── refs/
│   ├── marketing-context-template.md
│   ├── postiz.md            # MCP wiring, auth, schedulePostTool conventions
│   └── voice-rules.md       # hard bans / anti-AI-slop quality bar (adapted from ECC marketing-agent)
└── scripts/
```

## Commands

### `/gtm:init`

1. Prereq gate: `gh` auth OK; Postiz MCP reachable (backend URL + API key env var).
2. Detect product info from README/repo.
3. If `.agents/product-marketing.md` missing → run marketingskills `product-marketing` interview.
4. `integrationList` → channel picker: per channel set ownership (`auto|draft|manual`), account
   voice (`brand|founder`), cadence, content types.
5. Write `marketing-context.md` + `.agents/product-marketing.md` + `docs/gtm/` scaffold.
6. Re-init guard identical to sdlc `/init` (keep / merge / rerun).

### `/gtm:pulse` — core loop pass

1. **Read config** — marketing-context + product-marketing.
2. **Git scan** — `git log --since=<watermark>`: releases, merged PRs, changelog → shipped-work
   candidates.
3. **Engagement poll** (non-fatal) — GitHub-side listening via `gh api`: new stars/forks, issues,
   discussions, praise mentions. Praise → `docs/gtm/social-proof.md`. Questions worth answering →
   reply drafts in `queue/` (drafts only — replies are NEVER auto-sent).
4. **Calendar fill** — strategist merges candidates with evergreen calendar
   (`docs/gtm/calendar.md`), picks items due this pass.
5. **Draft** — content-writer per item per channel: pulls `integrationSchema` (limits, media
   rules), writes copy in channel's account voice, attaches generated image/short-video where the
   channel wants it. All links carry `?utm_source=<channel>&utm_campaign=<item-slug>`.
6. **Copy-review gate** — marketingskills `copy-editing` + `refs/voice-rules.md`. Nothing reaches
   Postiz without passing.
7. **Publish stage** — `schedulePostTool`: `auto` → scheduled post; `draft` → Postiz draft;
   `manual` → asset file in `docs/gtm/queue/`.
8. **State update** — `docs/gtm/state.json`: watermark SHA, content log (an item never posts twice
   to the same channel).
9. **Digest** — N drafted / N scheduled / N queued for human / what needs approval.

Designed idempotent + resumable → runnable via native `/loop`, scheduled cloud agent, or manually.
`--dry-run`: full pass, drafts to files, zero Postiz calls.

### `/gtm:launch`

Positioning locked first (ECC ordering), then the launch asset list: landing site (delegates to
`/gtm:site`), ~90s demo **script + storyboard** (production is `manual` — Postiz video tool is
short-form social, not terminal demos; record with asciinema/VHS/Remotion or human), brand kit
(reuses `brand/` + `nightshift-design`), launch post batch across channels,
`directory-submissions` checklist, coordinated launch-day calendar (Show HN + Product Hunt +
social blast + article cross-posts). Human-owned channels (HN, PH, aged-account Reddit) always
land in `queue/`.

### `/gtm:report`

Primary KPI from config (nightshift: `github_stars` via `gh api`) + Postiz analytics secondary.
Correlates KPI deltas with post timing via UTM convention. Harvests testimonials. Outputs digest +
calendar adjustments (feeds next pulse).

### `/gtm:site`

marketingskills `copywriting` + `cro` produce copy → `nightshift-design` brand tokens → build
handoff: sdlc installed → dispatch its web-engineer; else write `docs/gtm/site-brief.md`.

### `/gtm:docs`

marketingskills `ai-seo` + `content-strategy` + `schema` audit docs → doc-improvement PRs
(docs are repo artifacts; git flow is natural).

## Config schema — `.claude/project/marketing-context.md`

- **Product**: name, one-liner, repo, landing URL
- **KPI**: primary metric + source; secondary = Postiz analytics
- **Postiz**: backend URL, API key **env var name** (never the key)
- **Channels**: one row per Postiz integration — ownership `auto|draft|manual`, voice
  `brand|founder`, cadence, content types
- **Voice**: project voice + hard-bans pointer
- **Cadence**: pulse frequency, quiet days
- **UTM convention**

State lives in repo (`docs/gtm/`), not `.claude/`: reviewable, committable, PR-able, survives
machine changes.

## Autonomy model

Three-state per channel, honest about agent-vs-human channel ownership:

| State | Behavior |
|---|---|
| `auto` | Agent schedules + publishes unattended (brand accounts, once trust built) |
| `draft` | Lands as Postiz draft; human approves in Postiz UI (default for new channels) |
| `manual` | Asset file in `queue/`; human posts (HN, PH, Reddit, founder account) |

Graduation path draft → auto is a one-word config change per channel.

**Never automated:** reply sending, HN/Product Hunt posting (no Postiz integration; live presence
required), demo video recording. Reddit is Postiz-supported and defaults to `manual`, but is
config-overridable to `draft`/`auto` by a founder who accepts the subreddit-rules risk.

## Companion change (sdlc-side)

**PR-badge viral loop** — highest-leverage marketing asset: every PR nightshift opens carries a
footer badge "🌙 Shipped overnight by nightshift" + install link (config opt-out). Zero marginal
cost, compounds with usage, reaches exactly the right audience. Small sdlc change, own ticket,
not part of the gtm plugin build.

## Error handling

- Postiz unreachable → publish stage writes drafts to `queue/`; next pulse retries.
- Empty git scan → calendar-only pass. Both empty → no-op exit; no forced content.
- Engagement poll / analytics failures → non-fatal; pulse degrades to draft-only, never blocks.
- Dedupe guard via content log prevents repeats across passes.

## Testing & acceptance

- `--dry-run` on pulse/launch.
- Copy-review gate mandatory before any `schedulePostTool` call.
- **Acceptance = nightshift's own launch**: the plugin executes it (`/gtm:init` →
  `/gtm:launch` → `/gtm:pulse` on loop), dogfooding "we market nightshift with nightshift".

## Build order (each phase shippable)

1. Scaffold plugin + `/gtm:init` + context template
2. `/gtm:pulse` in draft-mode — minimum viable loop
3. `/gtm:report` — KPI tracking + social-proof harvest
4. `/gtm:launch` + `/gtm:site` + `/gtm:docs`
5. Engagement poll + sdlc PR-badge companion ticket

## Non-goals (v1)

- Email / newsletter sequences (no list yet; Postiz is not email)
- Paid ads
- Community ops (Discord/Slack)
- X/Reddit listening APIs (GitHub-side listening only in v1)
- Automated reply sending (never, not just v1)
- Long-form video production (scripts/storyboards only)

## Key references

- NA-2 — GTM plugin Epic, source of truth (first workload = nightshift launch; KPI: maximize GitHub stars)
- [marketingskills](https://github.com/coreyhaines31/marketingskills) — skill dependency
- [Postiz MCP](https://docs.postiz.com/mcp/introduction) — 9 tools; `schedulePostTool` supports draft/schedule/publish
- [ECC marketing-agent](https://github.com/affaan-m/ECC/blob/main/agents/marketing-agent.md) — copy-review gate, positioning-first ordering, hard-bans quality bar
