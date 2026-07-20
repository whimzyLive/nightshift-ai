---
title: What is the gtm plugin
description: Why the gtm plugin exists, how its commands and agents relate, and how it mirrors the sdlc plugin
related-adrs: []
---

# What is the gtm plugin

The `gtm` plugin is the marketing counterpart to the `sdlc` plugin. Where sdlc gives a repository a
version-controlled software-delivery foundation — agents, config, and durable artifacts that live
in the tree and travel with the code — gtm gives that same repository a version-controlled
go-to-market foundation. The premise is the same in both: marketing work, like engineering work, is
better when its context, its decisions, and its outputs are checked in, reviewed, and reproducible,
rather than kept in a founder's head or scattered across SaaS dashboards. gtm exists so that "how
this product is positioned, what channels it publishes to, and what its landing page says" is
answerable from the repo itself.

For the sdlc side of that comparison, see [what-is-the-sdlc-plugin.md](what-is-the-sdlc-plugin.md).

## Why a foundation before any action

The organizing idea behind gtm is config-before-action. Nothing productive happens until the repo
has a marketing foundation, and establishing that foundation is a deliberate, gated first step
rather than a side effect of the first task you run. `/gtm:init` is that step, and every other
command hard-requires the two files it writes:

- `.claude/project/marketing-context.md` — gtm's operational config: the product basics, the Postiz
  backend URL, the name of the Postiz API-key environment variable, per-channel settings, the KPI
  definition, and any voice overrides. This plugin's SessionStart hook auto-loads it each session.
- `.agents/product-marketing.md` — the marketingskills canonical product-context document
  (positioning, ICP, messaging), authored and maintained by the marketingskills `product-marketing`
  skill that `/gtm:init` invokes.

The reason to insist on this ordering is that marketing output is only as good as the positioning
behind it. Copy written without locked product context is guesswork; a channel published to without
agreed ownership rules is a liability. By making the foundation a precondition, gtm guarantees that
by the time you ask it to write a landing page or audit your docs, it already knows who the product
is for and how it should sound. `/gtm:init` reinforces this with an all-or-nothing write: it stages
its config under a temp directory and only moves files into place once every write has succeeded, so
a failed prerequisite never leaves half-written config behind. It is also safe to re-run, offering
keep, merge, or full-rerun paths rather than silently overwriting existing choices.

## The three commands and how they relate

The command surface is small and layered. `/gtm:init` sits underneath the other two, which each
consume the foundation it establishes and produce a different durable artifact.

`/gtm:init` bootstraps the foundation. It installs and gates on the dependencies, checks that Postiz
is reachable and authenticated, detects product information from the repo, runs the
product-marketing interview, configures each channel, defines the KPI, and writes the config and the
`docs/gtm/` scaffold. It does all of this in-command with no agent dispatch, because setup is a
linear gated sequence, not delegated work.

`/gtm:site` produces landing-page copy. It is a thin orchestrator that holds no copy logic itself: it
dispatches the `content-writer` agent for the copy, runs the shared copy-review gate against the
plugin's voice rules layered with any project voice overrides, applies the nightshift-design brand
tokens, and writes the result to `docs/gtm/site-brief.md`. That brief — a page map, the copy deck,
and a full SEO layer of meta/OG tags, JSON-LD, and an llms.txt recommendation — is the deliverable.
Building an actual site from the brief is a separate, founder-initiated step; `/gtm:site` never
builds or dispatches build agents, even when the sdlc plugin is present, because a repo with a brief
ready may still lack the frameworks a build needs.

`/gtm:docs` audits the documentation already in the repo. It measures the README and everything
under `docs/**` against the marketingskills `ai-seo` and `content-strategy` guidance and opens the
fewest improvement PRs the scope allows, each citing the specific audit finding it fixes. A clean
audit, or a `--dry-run`, opens nothing. Its bias toward the minimum number of PRs is deliberate:
documentation improvements should arrive as small, reviewable, individually-justified changes, not
as one sweeping rewrite.

To actually run these commands, see the tutorial
[getting-started-with-gtm.md](../tutorials/getting-started-with-gtm.md) and the how-to guide
[generate-landing-page-copy.md](../how-to/generate-landing-page-copy.md).

## The brief as a durable artifact

`/gtm:site` illustrates a second principle that runs through the plugin: the brief is durable, and
it is the handoff. Rather than treating generated copy as ephemeral chat output, gtm writes it to a
tracked file with a provenance header recording when and by which command it was generated. That
makes the copy reviewable in a pull request, diffable across regenerations, and legible to whatever
builds the site later — human or another plugin. The re-run guard around the brief (refine,
regenerate, or skip) exists precisely because the file is treated as an asset worth protecting, not
a throwaway. This mirrors how sdlc treats its specs and plans: the artifact in the tree, not the
conversation that produced it, is the source of truth.

## The agent roster

gtm carries three agents, each dispatched by a command rather than invoked directly:

- **product-marketing-manager** turns a vague marketing request or the stored product context into a
  GTM brief — positioning, messaging, target audience, channel rationale, and launch angle. It
  produces a brief, not a campaign execution, and is the entry point for a new marketing initiative
  once the foundation exists.
- **content-writer** produces customer-facing copy. For a landing page it returns a page map, copy
  deck, conversion pass, and full SEO layer. It hard-requires locked product-marketing context and
  refuses to draft without it, which is the same config-before-action discipline enforced at the
  agent boundary. It is dispatched by `/gtm:site`, never called inline.
- **docs-auditor** performs the `/gtm:docs` audit — grading existing docs against the ai-seo and
  content-strategy guidance and opening the minimal set of improvement PRs. Like content-writer, it
  is dispatched only by its command, never invoked directly.

The division of labor echoes sdlc's: commands orchestrate and gate; agents do the domain work in
isolation with the tools they need.

## Postiz as the publishing backend

gtm does not implement its own social or channel publishing. It delegates all of that to Postiz,
reached through the `postiz` skill (from the auto-installed `postiz@postiz-agent` dependency), which
wraps the Postiz CLI for auth, posting, uploads, integrations, and analytics. Every Postiz
operation across the plugin — from init's reachability gate to any downstream publish — goes through
that skill; gtm never hand-rolls HTTP against Postiz.

Because publishing is real and consequential, gtm makes channel behavior explicit rather than
implicit. At init time each channel Postiz reports is configured along four axes:

- **Ownership** — whether posts to this channel are published automatically (`auto`) or staged as
  drafts for human approval (`draft`, the safe default). A channel is graduated from `draft` to
  `auto` by re-running `/gtm:init` and changing its ownership, so the more permissive setting is
  always a deliberate, recorded choice.
- **Voice** — any per-channel tone adjustment.
- **Cadence** — how often the channel should publish.
- **Content types** — what kinds of content belong on it.

Storing these per-channel settings in the checked-in config is what lets gtm behave differently and
predictably on each channel without re-asking every session.

The backend URL and the API key are split by sensitivity, which reflects a considered stance on
secrets: the Postiz backend URL is a config token and is persisted to `marketing-context.md`,
whereas the API key is never written to disk — only the name of the environment variable that holds
it is stored, and the value must stay in your shell or `.env`.

## The KPI concept

gtm also gives the foundation a single headline metric. At init you name the KPI that matters and
choose its source: a managed source (today, GitHub stars, read via the `gh` CLI against the
product's repo), a custom command, or a custom endpoint. init verifies the source by reading one
live numeric value at configuration time and refuses to write a KPI it could not probe — the same
"never persist against a broken dependency" posture applied to the Postiz gate. The point is not the
number itself but that the repo carries a defined, verified way to read its own progress, rather than
an aspirational metric no tool can actually fetch.

## Dependencies and standalone posture

gtm depends on exactly two cross-marketplace plugins, both auto-installed with it:
`marketing-skills@marketingskills` (the 47-skill marketingskills library, of which gtm uses
`product-marketing`, `launch`, `content-strategy`, `copywriting`, `ai-seo`, `content-strategy`, and
`copy-editing`) and `postiz@postiz-agent` (the Postiz publishing backend). Notably, gtm does _not_
depend on the sdlc plugin: every shared script it needs is vendored into its own `scripts/`
directory, so it is fully standalone. The two plugins are siblings that mirror each other's design,
not a stack where one requires the other. You can adopt gtm on a repo that has never seen sdlc, and
vice versa.

## How it mirrors sdlc

The resemblance to sdlc is structural, not incidental, and it is the fastest way to understand gtm
if you already know sdlc:

- Both are bootstrapped by an `init` command that gates on prerequisites and writes a
  version-controlled foundation the rest of the plugin depends on.
- Both put durable artifacts in the tree — sdlc its specs and plans, gtm its marketing context and
  site brief — and treat those files, not the conversations, as the source of truth.
- Both use thin orchestrating commands that dispatch isolated domain agents rather than doing the
  work inline.
- Both refuse to proceed on a broken or missing prerequisite, and both stage writes so a failure
  never leaves a half-configured repo.

One deliberate divergence is worth noting: gtm's per-session plugin-root marker
(`.claude/.gtm-plugin-root`) is gitignored, because it caches a machine-absolute path regenerated
each session, whereas sdlc commits its equivalent marker. The difference reflects what each marker
holds, not a disagreement about how the plugins should work.

## Related decisions

This repository has no `docs/adr/` directory, so there are no ADRs for this page to reference. If
one is added later for a gtm design decision discussed here, link it from this section and list it
in the `related-adrs` frontmatter.
