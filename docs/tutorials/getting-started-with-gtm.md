---
title: Getting started with gtm
description: Bootstrap a marketing foundation for your repo and produce your first landing-page copy brief with the gtm plugin
related-adrs: []
---

# Getting started with gtm

In this tutorial you'll stand up the gtm marketing foundation for a repository and produce your
first landing-page copy brief. You'll install the plugin, connect it to a running Postiz instance,
run `/gtm:init` to bootstrap the foundation, and finish by running `/gtm:site` to generate a
handoff brief you can see on disk. By the end you'll have four marketing files written into your
repo and a copy brief ready to build from.

## Prerequisites

Before you start, make sure you have:

- **Claude Code** running, open in the repository you want to set up.
- **A running Postiz instance** you can reach, plus its **API key**. This can be Postiz Cloud
  (`https://api.postiz.com`) or a self-hosted backend. gtm will not write any config until it can
  reach Postiz, so have the backend URL and key ready.
- The **gtm plugin** available from the `nightshift` marketplace. If your Claude Code doesn't
  already know that marketplace, add it once with
  `/plugin marketplace add <path-or-git-url-to-the-nightshift-repo>`.

## Step 1: Install the gtm plugin

Install the plugin from the nightshift marketplace:

```
/plugin install gtm@nightshift
```

You should see the plugin install and report success. Installing gtm also pulls its two
dependencies, `postiz@postiz-agent` and `marketing-skills@marketingskills`, so you don't need to
install those yourself. Once it finishes, the `/gtm:init` and `/gtm:site` commands are available in
this repo.

## Step 2: Point gtm at your Postiz instance

gtm reads your Postiz backend URL and API key from two environment variables. Export both in the
same shell session that Claude Code is running in:

```bash
export POSTIZ_API_URL="https://api.postiz.com"
export POSTIZ_API_KEY="your-postiz-api-key"
```

Use your own backend URL if you self-host, and your own key. To confirm the key is set, print just
its length so you don't echo the secret:

```bash
echo "${#POSTIZ_API_KEY}"
```

You should see a number greater than zero. That's your signal that gtm's Postiz gate will find the
key when you run `/gtm:init` next.

## Step 3: Bootstrap the marketing foundation

Run the init command:

```
/gtm:init
```

`/gtm:init` walks you through the setup interactively. It confirms the Postiz backend URL (accept
the cloud default when prompted), checks that Postiz authenticates, then scans your repo to detect
your product name, one-liner, repository, and landing URL. It invokes the `product-marketing` skill
to build your product-context document, walks you through your Postiz channels one at a time, and
asks for the one metric that matters most (your KPI). Answer each prompt as it appears.

When it finishes, you should see a summary listing the files it wrote:

```
Files written:
- .claude/project/marketing-context.md — gtm's operational config
- .agents/product-marketing.md — the canonical product-context doc
- docs/gtm/README.md, docs/gtm/digests/.gitkeep, docs/gtm/briefs/.gitkeep — the working-directory scaffold
- .claude/.gtm-plugin-root (gitignored) — per-session plugin-root cache
```

Confirm the two key files are really there:

```bash
ls .claude/project/marketing-context.md .agents/product-marketing.md
```

You should see both paths printed back with no error. Your marketing foundation now exists.

## Step 4: Generate your first landing-page copy brief

With the foundation in place, produce your landing-page copy:

```
/gtm:site
```

`/gtm:site` writes a marketing brief and generates the copy, runs it through the copy-review gate,
applies your brand tokens, and writes the result to a single handoff file. When it finishes, you
should see it report a PASS from the copy-review gate and name the brief path
`docs/gtm/site-brief.md`.

Confirm the brief was written:

```bash
ls docs/gtm/site-brief.md
```

You should see the path printed back. Open it and you'll find the full landing-page copy deck plus
its SEO layer, the deliverable this tutorial set out to produce.

## What you built

You now have a version-controlled marketing foundation for your repo and your first landing-page
copy brief:

- `.claude/project/marketing-context.md` — gtm's operational config (product basics, Postiz
  backend URL, channels, and your KPI).
- `.agents/product-marketing.md` — your canonical product-context document.
- `docs/gtm/` — the marketing working-directory scaffold.
- `docs/gtm/site-brief.md` — the landing-page copy brief, ready to build from.

To build a real page from that brief, follow
[How to generate landing-page copy with gtm](../how-to/generate-landing-page-copy.md). To
understand what the plugin is doing under the hood and how its pieces fit together, read
[What is the gtm plugin](../concepts/what-is-the-gtm-plugin.md).
