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
| [marketing-skills@marketingskills](https://github.com/coreyhaines31/marketingskills) (cross-marketplace dep) | Expertise: copywriting, cro, launch, ai-seo, content-strategy, directory-submissions, copy-editing, product-marketing |
| `gtm` plugin | Orchestration: agent roles, git-driven loop, state, gates, KPI tracking |
| [`postiz@postiz-agent`](https://github.com/gitroomhq/postiz-agent) — the `postiz` skill/CLI | Hands: channel discovery (`postiz integrations`), platform rules (integration schema via the CLI), draft/schedule/publish (`postiz posts:create`), media upload (`postiz upload`). The mechanism is the postiz **CLI/skill**, not MCP. |
| `sdlc` plugin (optional) | Build handoff for landing site / docs PRs — an integration only, **not** a manifest dependency |
| `.claude/project/marketing-context.md` | Per-repo config (same pattern as sdlc's `project-context.md`) |

> **AI image / short-video generation** (the old Postiz MCP `generateImageTool` / `generateVideoTool`)
> has **no postiz-CLI equivalent**. The generation mechanism is an **open decision for the
> content-writer story**: either local generation + `postiz upload`, or adding the Postiz MCP server
> alongside the `postiz` skill. Not decided here; not needed by `/gtm:init`.

> **Rejected option:** the `deepline-gtm` skill (skills.sh / code.deepline.com) was evaluated and
> **rejected** — it is a sales-outbound prospecting/enrichment vendor (paid API, account required),
> not marketing-brief authoring, and its install path relies on sandbox-bypass npm-prefix +
> custom-registry patterns that fail our supply-chain bar.

`/gtm:init` also writes `.agents/product-marketing.md` — the marketingskills `product-marketing`
skill's expected context file, which that skill creates and maintains — so upstream skills work
unmodified.

## Plugin layout

```
plugins/gtm/
├── .claude-plugin/plugin.json   # deps: postiz@postiz-agent, marketing-skills@marketingskills — NO superpowers, NO sdlc dep
├── agents/
│   ├── product-marketing-manager.md # PMM — marketing mirror of sdlc's product-manager: vague request → GTM brief
│   ├── marketing-strategist.md  # positioning, calendar, channel mix
│   ├── content-writer.md        # all copy production: landing-page + per-channel drafts + media; hard-requires product-marketing context
│   └── growth-analyst.md        # KPI + analytics pull, digest, calendar tuning, social-proof harvest
├── commands/
│   ├── init.md      # scaffold config, verify Postiz via postiz CLI, product-marketing context
│   ├── pulse.md     # one engine pass — THE loop body
│   ├── launch.md    # launch campaign (nightshift launch asset list)
│   ├── report.md    # analytics digest + recommendations
│   ├── site.md      # landing page: copy → brand → build handoff
│   └── docs.md      # docs-SEO: audit → doc-improvement PRs
├── refs/
│   ├── marketing-context-template.md
│   ├── postiz-verify.md        # postiz CLI/skill gate: auth:status, env-var contract, posts:create conventions
│   └── voice-rules.md          # hard bans / anti-AI-slop quality bar (adapted from ECC marketing-agent)
└── scripts/                    # vendored standalone set: session-complete.sh, cleanup-tmp.sh, tmp-dir.sh, session-key.sh (no sdlc dependency)
```

**Dependencies (manifest):** two cross-marketplace plugins — `postiz@postiz-agent` and
`marketing-skills@marketingskills` (marketplace `marketingskills`, repo `coreyhaines31/marketingskills`,
v2.6.x). **No `superpowers` dependency** — nothing in gtm invokes a superpowers skill (the earlier
inclusion copied sdlc's manifest shape without the usage; add it back only when a future story
actually uses one). There is **no `sdlc` dependency**: gtm vendors the shared script set
(`session-complete.sh` / `cleanup-tmp.sh` / `tmp-dir.sh` / `session-key.sh`) into
`plugins/gtm/scripts/`. `sdlc` stays an **optional build-handoff integration** (site / docs), not a
manifest dep. (`marketplace.json` `allowCrossMarketplaceDependenciesOn` gains `postiz-agent` +
`marketingskills`; the pre-existing `claude-plugins-official` entry stays for sdlc's superpowers dep.)

### `product-marketing-manager` agent (PMM)

The marketing mirror of sdlc's `product-manager` (vague feature → PRD): the PMM takes a vague
marketing request / product context → a **GTM brief** (positioning, messaging, target audience,
channel rationale, launch angle), written to `docs/gtm/briefs/<date>-<slug>.md`. It uses the
marketingskills skills (`product-marketing` for context; `launch` / `content-strategy` /
`copywriting` as needed) and the `postiz` skill for any Postiz operation (**never raw HTTP**). NA-3
ships the agent definition; the brief-producing workflows belong to downstream stories
(NA-4..NA-8, NA-11).

### `content-writer` agent

The single copy-production role (the consultancy's copywriter / conversion copywriter): **all**
customer-facing copy is drafted by this agent, never inline in a command. Commands stay thin glue —
they dispatch the writer and handle orchestration/handoff.

**Context contract (enforced in the agent definition, inherited by every consumer):** before
drafting anything, the agent MUST read `.agents/product-marketing.md` (positioning/ICP/audience)
and `refs/voice-rules.md`, and MUST STOP with a clear error if the product-marketing context is
missing — copy is never produced without locked positioning.

**Delivery is split across stories:** **NA-6 ships the agent definition** (context contract +
landing-page capability, using marketingskills `copywriting` + `cro`); **NA-8 extends it** with
per-channel drafts, media generation, and postiz integration-schema compliance. Hence the
`NA-6 Blocks NA-8` dependency edge.

## Commands

### `/gtm:init`

`/gtm:init` does **all its own setup work in-command** (mirrors sdlc's `/init`) — no agent dispatch.
Step ladder (matches the NA-3 spec, `docs/superpowers/specs/NA-3.md`):

0. **Re-init guard** — identical to sdlc `/init` (keep / merge / rerun); never silently overwrites.
1. **Dependency check** — verify the `postiz@postiz-agent` (postiz skill) and
   `marketing-skills@marketingskills` (product-marketing skill) plugins are installed; install
   (`claude plugin marketplace add … → claude plugin install …@… --scope project`) or instruct the
   user; STOP if either cannot be installed.
2. **Postiz gate** — via the postiz CLI: env vars `POSTIZ_API_URL` + `POSTIZ_API_KEY` present
   (names-only persisted, values never written to disk) **and** `postiz auth:status` reports
   authenticated. STOP + write nothing on failure.
3. **Product detection** — read-only scan of README / repo / `package.json` for name, one-liner,
   repo, landing URL.
4. **Product-marketing context** — invoke the marketingskills `product-marketing` **skill** (seeded
   with the Step-3 detection) to create/maintain `.agents/product-marketing.md` (auto-draft →
   founder-corrects, or from-scratch interview). The skill owns that file.
5. **Atomic write** of init's own artifacts — `marketing-context.md` + the `docs/gtm/` scaffold +
   the gitignored `.claude/.gtm-plugin-root` marker; staged then moved only if all writes succeed;
   verifies `.agents/product-marketing.md` exists.
6. **Post-init checklist** — env vars to keep set, how to commit, and the follow-up stories.
7. **Release** the session.

> **Re-homed from the old init design:** the **channel picker** (old step 4 — `integrationList` →
> per-channel ownership/voice/cadence) and **KPI setup orchestration** (old step 5 — metric +
> provider-catalogue source + verification probe) are **not** part of NA-3's init. They are
> later-story extensions of init (or their own commands): the channel picker belongs to **NA-4**
> (channel ownership/voice/cadence) and KPI setup to **NA-6** (KPI metric + source). The capability
> is not dropped — it is re-homed to the stories that own it.

### `/gtm:pulse` — core loop pass

1. **Read config** — marketing-context + product-marketing.
2. **Git scan** — `git log --since=<watermark>`: releases, merged PRs, changelog → shipped-work
   candidates.
3. **Engagement poll** (non-fatal, optional) — polls the engagement sources configured in
   marketing-context; skipped when none configured. v1 ships one provider: GitHub via `gh api`
   (new stars/forks, issues, discussions, praise mentions) — nightshift's choice, not a plugin
   default. Praise → `docs/gtm/social-proof.md`. Questions worth answering → reply drafts in
   `queue/` (drafts only — replies are NEVER auto-sent).
4. **Calendar fill** — strategist merges candidates with evergreen calendar
   (`docs/gtm/calendar.md`), picks items due this pass.
5. **Draft** — content-writer per item per channel: pulls the channel's postiz integration schema
   (limits, media rules), writes copy in channel's account voice, attaches generated image/short-video
   where the channel wants it (generation mechanism per the open decision above). All links carry
   `?utm_source=<channel>&utm_campaign=<item-slug>`.
6. **Copy-review gate** — marketingskills `copy-editing` + `refs/voice-rules.md`. Nothing reaches
   Postiz without passing.
7. **Publish stage** — via the postiz CLI (`postiz posts:create`; media via `postiz upload`):
   `auto` → scheduled post; `draft` → Postiz draft; `manual` → asset file in `docs/gtm/queue/`.
8. **State update** — `docs/gtm/state.json`: watermark SHA, content log (an item never posts twice
   to the same channel).
9. **Digest** — N drafted / N scheduled / N queued for human / what needs approval.

Designed idempotent + resumable → runnable via native `/loop`, scheduled cloud agent, or manually.
`--dry-run`: full pass, drafts to files, zero Postiz calls.

### `/gtm:launch`

Positioning locked first (ECC ordering), then the launch asset list: landing site (delegates to
`/gtm:site`), ~90s demo via the **VHS + Remotion pipeline** — engine generates a VHS `.tape`
script (deterministic terminal recording, re-recordable each release, CI-able) plus a Remotion
composition that wraps the capture into the final cut (captions, brand frames, pacing); human
voiceover optional. Brand kit
(reuses `brand/` + `nightshift-design`), launch post batch across channels,
`directory-submissions` checklist, coordinated launch-day calendar (Show HN + Product Hunt +
social blast + article cross-posts). Human-owned channels (HN, PH, aged-account Reddit) always
land in `queue/`.

### `/gtm:report`

User-defined primary KPI from config — metric + source, no plugin default (nightshift:
`github_stars` via `gh api`) — + Postiz analytics secondary.
Correlates KPI deltas with post timing via UTM convention. Harvests testimonials. Tracks per-channel
approve-without-edit streaks and recommends draft→auto promotion after a sustained streak (default
10 consecutive untouched drafts) — never promotes on its own. Outputs digest +
calendar adjustments (feeds next pulse).

### `/gtm:site`

Thin orchestrator — no copy logic in the command. Dispatch the `content-writer` agent
(task = landing page; skills `copywriting` + `cro`; the agent's context contract enforces
`.agents/product-marketing.md` + voice rules) → apply `nightshift-design` brand tokens → build
handoff: sdlc installed → dispatch its web-engineer; else write `docs/gtm/site-brief.md`.

### `/gtm:docs`

marketingskills `ai-seo` + `content-strategy` + `schema` audit docs → doc-improvement PRs
(docs are repo artifacts; git flow is natural).

## Config schema — `.claude/project/marketing-context.md`

- **Product**: name, one-liner, repo, landing URL
- **KPI**: user-defined primary metric + source (no plugin default; nightshift picks `github_stars`); source is a provider reference — managed (v1: `github`) or `custom` with a command/endpoint that returns the current value; secondary = Postiz analytics. Engagement sources listed separately, optional
- **Postiz**: `POSTIZ_API_URL` env-var **name** (default `POSTIZ_API_URL`; backend URL — cloud or self-hosted — read from the env var by the postiz CLI) + API key **env-var name** (default `POSTIZ_API_KEY`; never the key). Names-only persisted.
- **Channels**: one row per Postiz integration — ownership `auto|draft|manual`, voice
  `brand|founder`, cadence, content types
- **Voice**: project voice layered over the plugin's ECC-derived anti-slop defaults
  (`refs/voice-rules.md`); projects may extend or override — copy gate enforces the merged result
- **Cadence**: pulse frequency (default: daily pulse; calendar gates output at ~3 posts/week/channel),
  quiet days (default: weekends)
- **UTM convention**

State lives in repo (`docs/gtm/`), not `.claude/`: reviewable, committable, PR-able, survives
machine changes. Content log is append-only JSONL (dedupe key: item+channel) with a git
union-merge attribute so concurrent appends merge cleanly; watermark resolves to the newest SHA on
merge. The publish stage runs only on the default branch — elsewhere pulse auto-degrades to
dry-run. Pulse digests print in-session AND append under `docs/gtm/digests/` for unattended runs.

## Autonomy model

Three-state per channel, honest about agent-vs-human channel ownership:

| State | Behavior |
|---|---|
| `auto` | Agent schedules + publishes unattended (brand accounts, once trust built) |
| `draft` | Lands as Postiz draft; human approves in Postiz UI (default for new channels) |
| `manual` | Asset file in `queue/`; human posts (HN, PH, Reddit, founder account) |

Graduation path draft → auto is a one-word config change per channel.

**Never automated:** reply sending, HN/Product Hunt posting (no Postiz integration; live presence
required), publishing the demo video without human review. Reddit is Postiz-supported and defaults
to `manual`, but is config-overridable to `draft`/`auto` by a founder who accepts the
subreddit-rules risk. Demo video is machine-rendered (VHS + Remotion) but human-reviewed before it
ships; voiceover optional/human.

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
- Copy-review gate mandatory before any postiz publish (`posts:create`) call.
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
- X/Reddit listening APIs (GitHub engagement provider is the only listening source in v1 — optional, config-enabled)
- Automated reply sending (never, not just v1)
- Free-form/long-form video beyond the VHS + Remotion demo pipeline (YouTube tutorials, talking-head)

## Key references

- NA-2 — GTM plugin Epic, source of truth (first workload = nightshift launch; KPI: maximize GitHub stars)
- NA-3 — `docs/superpowers/specs/NA-3.md` — `/gtm:init` technical spec (the locked init/deps decisions this doc aligns to)
- [marketing-skills@marketingskills](https://github.com/coreyhaines31/marketingskills) — marketing-skills plugin dependency (marketplace `marketingskills`, v2.6.x)
- [postiz@postiz-agent](https://github.com/gitroomhq/postiz-agent) — the `postiz` skill/CLI: `auth:status`, `posts:create`, `upload`, `integrations`, `analytics` across 28+ platforms (env: `POSTIZ_API_URL` + `POSTIZ_API_KEY`)
- [ECC marketing-agent](https://github.com/affaan-m/ECC/blob/main/agents/marketing-agent.md) — copy-review gate, positioning-first ordering, hard-bans quality bar
