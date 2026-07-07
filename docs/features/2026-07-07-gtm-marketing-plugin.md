# PRD — GTM marketing plugin for nightshift marketplace

- **Epic:** NA-2
- **Date:** 2026-07-07
- **Status:** Ready for spec
- **Source of truth:** NA-2 Epic + approved design spec `docs/superpowers/specs/2026-07-07-gtm-plugin-design.md`

---

## Problem Statement

Developer founders ship products that nobody sees. nightshift's existing `sdlc` plugin automates the
build side — issue to spec to plan to implementation to review to PR — but nothing automates
distribution. The moment code ships, the founder has to context-switch out of engineering and into
marketing: writing posts, cutting a demo, choosing channels, tracking whether any of it moves the
needle. That work is manual, easy to skip, and rarely done consistently, so good products stay
invisible. nightshift itself has the same problem: it needs a launch (landing site, demo, launch
posts, a growing following) with GitHub stars as the yardstick, and no tool yet turns its own shipped
work into that launch.

## Solution

A second nightshift plugin, `gtm` — a continuous "marketing while you sleep" engine that sits beside
`sdlc`. Where `sdlc` builds, `gtm` distributes. It reads what the team just shipped (releases, merged
PRs, changelog), turns each shipped item into channel-ready content in the project's voice, runs it
through a quality gate, and publishes it across social channels via Postiz — automatically for
trusted channels, as drafts or human-owned queue items for sensitive ones. It tracks a configurable
growth KPI (for nightshift, GitHub stars), correlates content to KPI movement, and tunes its own
calendar. It also runs one-off launch campaigns. The engine is idempotent and resumable, so it runs
unattended on a loop, on a schedule, or on demand — the founder stays in engineering while marketing
happens continuously in the background.

The plugin's first workload and acceptance test is nightshift's own launch: install it, run init,
run a launch campaign, then run the pulse loop — dogfooding "we market nightshift with nightshift."

## User Story

**As a** developer founder who has just shipped work with nightshift,
**I want** an agent that continuously turns my shipped work into reviewed, channel-appropriate
marketing content and publishes it while tracking my growth metric,
**So that** my product reaches customers and grows its following without me leaving engineering to do
marketing by hand.

## Acceptance Criteria

1. A founder can run an init command that verifies Postiz reachability, detects product info,
   presents a channel picker, and orchestrates KPI setup — founder defines the metric and its
   source (managed provider or custom command/endpoint), init handles that source's auth/env needs
   and proves it can read a value before writing config. Writes the marketing config plus a docs
   scaffold — with a re-init guard that offers keep / merge / rerun when config already exists.
   No KPI source is hardcoded or assumed.
2. A pulse pass reads config, scans git since the last watermark, drafts per-channel content in the
   configured voice, and passes every item through a copy-review gate before anything is published;
   no item reaches a channel without passing the gate.
3. Each channel obeys its configured ownership: `auto` publishes/schedules unattended, `draft` lands
   as a platform draft for human approval, `manual` writes an asset file to a human-owned queue.
4. A dry-run option runs a full pass, writes all drafts to files, and makes zero external publishing
   calls.
5. When Postiz is unreachable, the pulse pass degrades gracefully — it writes drafts to the queue,
   never blocks, and retries on the next pass; an empty git scan yields a calendar-only pass and a
   fully empty pass is a clean no-op with no forced content.
6. The engine never posts the same item to the same channel twice (dedupe via a committed content
   log/watermark) and every published link carries the configured UTM tags.
7. A launch command produces the full launch asset set (landing-site handoff, ~90s demo script and
   storyboard, brand kit reuse, launch-post batch, directory-submission checklist, coordinated
   launch-day calendar), with all trust-sensitive channels routed to the human queue.
8. A report command reads the user-defined primary KPI from config (metric + source — GitHub stars
   is nightshift's choice, not a plugin default) plus secondary analytics, correlates KPI movement
   with published content, harvests social proof, and outputs a digest with calendar adjustments.
9. Reply sending, Hacker News / Product Hunt posting, and demo-video recording are never automated —
   no Postiz integration exists for HN/PH and both demand live human presence; the engine only ever
   prepares drafts or queue items for a human on those. Reddit (a supported Postiz channel) defaults
   to `manual` but is config-overridable to `draft` / `auto` by a founder who accepts the
   subreddit-rules risk.
10. All engine state (watermark, content log, calendar, social proof, queue) lives in the repo as
    reviewable, committable files — not in hidden config.

## User Flows

### Flow A — Init (happy path)

1. Founder installs `gtm` alongside `sdlc` and runs the init command.
2. Engine checks prerequisites: Postiz reachable (backend URL + API key present).
3. Engine detects product info (name, one-liner, repo, landing URL) from the repository.
4. If the product-marketing context is missing, engine runs the product-marketing interview.
5. Engine lists available Postiz channels and presents a picker; founder sets per channel: ownership
   (`auto` / `draft` / `manual`), voice (`brand` / `founder`), cadence, and content types.
6. Init then orchestrates KPI setup: founder names the metric that matters to them and picks its
   source from the provider catalogue — a managed provider (GitHub at v1) or a custom source (any
   founder-supplied command or endpoint that returns the metric's current value). Init walks
   through whatever that source needs (auth, env vars), runs a verification probe to confirm a
   value can actually be read, and records the same for any optional engagement sources. Nothing
   is hardcoded to GitHub or any other platform.
7. Engine writes the marketing config, the product-marketing context, and the docs scaffold.
8. Founder commits the config — marketing setup is now version-controlled.

**Edge — config already exists:** engine detects existing config and offers keep / merge / rerun;
nothing is overwritten without the founder choosing.

**Edge — prerequisite missing:** Postiz unreachable, or auth missing for a selected KPI/engagement
provider → engine stops at the gate with a clear message on what to fix; no partial config is
written.

### Flow B — Pulse pass (happy path)

1. Engine reads the marketing config and product context.
2. Engine scans git since the last watermark for releases, merged PRs, and changelog entries →
   shipped-work candidates.
3. Engine polls the engagement sources defined in config — non-fatal; praise is recorded as social
   proof, answerable questions become reply *drafts* in the queue. (v1 ships a GitHub provider —
   stars/forks, issues, discussions; nightshift configures it. A product not centered on GitHub
   disables it or configures a different source; the poll is skipped entirely when no source is
   configured.)
4. Strategist merges candidates with the evergreen calendar and picks items due this pass.
5. Writer drafts each item per channel in the channel's voice, respecting each platform's limits and
   media rules, attaching generated image/short-video where the channel wants it; every link gets UTM
   tags.
6. Copy-review gate checks each draft against the voice/quality rules; failing drafts do not proceed.
7. Publish stage routes each passing item by ownership: `auto` → scheduled/published, `draft` →
   platform draft, `manual` → queue file.
8. Engine updates state (watermark, content log) so nothing repeats.
9. Engine emits a digest: N drafted / N scheduled / N queued for human / what needs approval.

**Edge — empty git scan:** engine runs a calendar-only pass (evergreen items due). If both git scan
and calendar are empty, engine exits as a clean no-op — it never fabricates content.

**Edge — engagement poll or analytics failure:** treated as non-fatal; the pass degrades to
draft-only and continues, never blocking on a listening/analytics error.

### Flow C — Launch campaign

1. Founder confirms the launch precondition: the plugin is publicly installable in one step
   (marketplace listing live) before any asset points at it.
2. Engine locks positioning first, reusing the locked brand (name "Nightshift", tagline "you sleep,
   it ships") and existing brand kit — no name validation pending.
3. Engine produces the launch asset set: landing-site handoff, ~90s demo script + storyboard (paste
   a ticket key → agents hand off → a PR opens → it fixes its own review → it merges), launch-post
   batch across channels, directory-submission checklist, and a coordinated launch-day calendar
   (Show HN + Product Hunt + social blast across X / LinkedIn / Bluesky + Reddit + long-form article
   cross-posted to dev.to / Hashnode / Medium with the demo video).
4. Trust-sensitive channels (Hacker News, Product Hunt, founder account, and Reddit unless
   explicitly overridden in config) are routed to the human queue — the engine prepares, a human
   posts.
5. Demo-video *recording* is a human/manual step; the engine delivers only the script and storyboard.

### Flow D — Postiz-unreachable degradation

1. During a pulse or launch publish stage, Postiz is unreachable.
2. Engine does not fail the pass; every item that would have been scheduled/drafted in Postiz is
   written to the human-owned queue instead.
3. Engine notes the degradation in the digest and leaves state so the next pass retries the same
   items (dedupe prevents double-posting once Postiz returns).

### Flow E — Manual-channel queue flow

1. For any `manual` channel (or any channel while Postiz is down), the engine writes a ready-to-post
   asset file (copy + media references + target channel) into the repo queue.
2. Digest lists what is queued and awaiting a human.
3. Founder opens the queue, reviews/edits, and posts to the human-owned channel themselves.
4. The item stays in the content log so it is not regenerated on the next pass.

## Out of Scope (v1)

Carried from the Epic's Out of Scope (v1):

- Email / newsletter sequences (no list yet; Postiz is not email).
- Paid ads.
- Community ops (Discord / Slack).
- Off-platform listening APIs for X / Reddit — the GitHub engagement provider is the only listening
  source shipped in v1 (optional, config-enabled).
- Automated reply sending — never, not just v1; replies are drafted for a human to send.
- Long-form / terminal-demo video production — scripts and storyboards only.
- The `sdlc` PR-badge viral-loop change — a related companion improvement tracked as its own ticket,
  not part of this plugin build.

## Open Questions

Carried from the Epic (6) plus new ones surfaced during PRD:

1. Postiz setup assumption per consumer (self-hosted backend URL + API key env var) — confirm
   expected deployment before init is specced. — Owner: Solutions Architect
2. Channel graduation policy — what signals justify promoting a channel from `draft` to `auto`? —
   Owner: Product
3. KPI provider catalogue beyond v1 — v1 ships the GitHub managed provider plus the custom
   command/endpoint source (the universal escape hatch). Which managed providers come next
   (npm downloads, site analytics, waitlist signups, marketplace installs)? — Owner: Product
4. Voice / quality-bar ownership — reuse the ECC hard-bans anti-slop rules vs project-specific voice;
   who approves the final bar? — Owner: Product
5. Demo-video production path (asciinema / VHS / Remotion / human) — which is the default
   recommendation for launch? — Owner: Product
6. marketingskills cross-marketplace dependency — versioning and availability guarantees for the
   required upstream skills. — Owner: Solutions Architect
7. (New) Pulse cadence defaults and quiet-day handling — what is the recommended default frequency
   for a new install, and how are quiet days expressed? — Owner: Product
8. (New) Content-log / watermark conflict handling — how does dedupe behave when the same repo is run
   from two machines or branches? — Owner: Solutions Architect
9. (New) Digest delivery surface — is the pulse digest terminal-only, a committed file, or both? —
   Owner: Product

## Dependencies

- **marketingskills plugin** — cross-marketplace skill dependency (copywriting, cro, launch, ai-seo,
  content-strategy, directory-submissions, copy-editing, product-marketing). Must be installed and
  available.
- **Postiz instance + API key** — reachable backend (self-hosted) and an API key exposed via an env
  var (never the key itself in config). Provides channel discovery, platform rules, draft/schedule/
  publish, and AI image / short-video generation.
- **GitHub CLI (`gh`)** — required only when the configured KPI or engagement source is GitHub
  (as it is for nightshift); products tracking a different metric skip this dependency.
- **`sdlc` plugin (optional)** — used for the landing-site and docs build handoff; when absent, the
  engine writes a brief instead of dispatching a build.

## Product Checks

- **Roles affected:** developer founder (primary operator), founder-as-marketer (configures channels
  / KPI / voice / cadence), nightshift maintainers (first consumers running the nightshift launch).
- **Mobile / offline:** N/A — `gtm` is a Claude Code CLI plugin; there is no mobile or offline
  surface. It does require network access for Postiz and GitHub, and degrades to local draft/queue
  files when Postiz is unreachable.
- **Surfaces:** the developer's terminal / Claude Code (commands: init, pulse, launch, report, site,
  docs); repo files under the marketing docs scaffold (config, calendar, state, social proof, queue);
  external social channels via Postiz; GitHub (KPI + engagement); optional landing-site / docs PRs.

## Further Notes

- The launch work is a **marketing surface only** — it never changes plugin functionality.
- The KPI framing is "maximize GitHub stars with no fixed numeric target"; every asset and channel is
  optimized to convert awareness into stars.
- All engine state is intentionally kept in the repo (reviewable, committable, PR-able) rather than
  in hidden local config, so marketing decisions are auditable and survive machine changes.
- Build order (from the design spec, each phase shippable): (1) scaffold + init; (2) pulse in
  draft-mode; (3) report + social-proof harvest; (4) launch + site + docs; (5) engagement poll +
  the sdlc PR-badge companion ticket.
