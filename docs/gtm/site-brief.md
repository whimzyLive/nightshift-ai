<!-- generated 2026-07-10 by /gtm:site -->

# Landing-page site brief — nightshift

_Produced by `content-writer` (task=landing-page), gated PASS by the /gtm:site copy-review gate (voice-rules.md hard bans + copy-editing criteria; project Voice overrides: none), branded from `brand/BRAND_KIT.md`. Repo: whimzyLive/nightshift-ai._

---

## 1. Page map / IA

**Site type:** SaaS marketing site (single flagship landing page for a free OSS plugin). Business goal is adoption — plugin installs and GitHub stars. One conversion-focused long-scroll home page now; future pages slotted for when docs/content exist.

**Primary conversion:** run the install command. **Secondary:** star the repo.

### Page hierarchy

```
Home (/)                        ← this landing page
├── How it works (/#how-it-works)      [on-page anchor now → future /how-it-works]
├── The team (/#agents)                [on-page anchor now → future /agents]
├── FAQ (/#faq)                        [on-page anchor]
└── [future-page slots]
    ├── Docs (/docs)                   [slot — not built this pass]
    ├── Agents reference (/agents)     [slot — deepen the 11-agent roster]
    ├── Changelog (/changelog)         [slot — Mintlify changelog per stack decision]
    └── Blog (/blog)                   [slot — NA-11+ content/customer stories]
```

### URL map

| Page              | URL                                           | Parent | Nav location    | Priority | Status      |
| ----------------- | --------------------------------------------- | ------ | --------------- | -------- | ----------- |
| Home / landing    | `/`                                           | —      | —               | High     | This pass   |
| How it works      | `/#how-it-works`                              | Home   | Header          | High     | Anchor now  |
| The team (agents) | `/#agents`                                    | Home   | Header          | Medium   | Anchor now  |
| FAQ               | `/#faq`                                       | Home   | Footer          | Medium   | Anchor now  |
| Docs              | `/docs`                                       | Home   | Header + footer | High     | Future slot |
| Agents reference  | `/agents`                                     | Home   | Footer          | Medium   | Future slot |
| Changelog         | `/changelog`                                  | Home   | Footer          | Low      | Future slot |
| GitHub repo       | `https://github.com/whimzyLive/nightshift-ai` | —      | Header + footer | High     | External    |

### Navigation spec

- **Header (left → right):** `🌙 nightshift` wordmark (links `/`) · How it works · The team · FAQ · GitHub (external) · **primary CTA button `Install the plugin`** (scrolls to hero/final install block). 4 nav links + 1 CTA.
- **Footer columns:**
  - **Plugin:** How it works · The team · FAQ · Docs (soon)
  - **Project:** GitHub · Changelog (soon) · MIT License · Issues
  - **Company:** whimzyLive
- **Breadcrumbs:** none (single-level page). Add when `/docs` and `/agents` ship.

### On-page section order (the scroll)

1. Hero (headline, subhead, install CTA, star CTA, `/auto` pipeline visual)
2. Proof bar (the numbers)
3. Problem — the connective tissue
4. How it works — the pipeline + the `/auto` run
5. The team — 11 agents, not a megaprompt
6. Why it's different — value themes
7. Objections / FAQ
8. Final CTA (recap + install + star)

### Internal linking plan

- Hero and final-CTA install blocks both point to the same install instructions (the primary conversion, reinforced top and bottom).
- Each header nav link is an on-page anchor; every section is reachable in one click.
- Hub-and-spoke deferred until `/docs` and `/blog` exist. When they land: home = hub; docs pages and blog posts link back to `/` and to `/#how-it-works`.
- No orphan risk this pass (single page). Future slots each need an inbound link from the footer at minimum before launch.

---

## 2. Copy deck

> Copy is sentence-case, lowercase `nightshift`, reworded to avoid sentence-initial `nightshift` where it would force a capital. Anything you'd type renders in JetBrains Mono (see §6 brand tokens).

### Section 1 — Hero

**Headline:** Your AI software team that ships while you sleep

**Subheadline:** A Claude Code plugin that turns one terminal into a full delivery team — product manager, architect, tech lead, engineers, and QA. It reads a Jira ticket and ships the spec, plan, code, and review.

**Primary CTA (install block):**
Label above the block: `Install in 60 seconds`

```
/plugin marketplace add whimzyLive/nightshift-ai
/plugin install sdlc@nightshift
```

Button/affordance: `Copy install command`

**Secondary CTA:** `Star nightshift on GitHub`

**Hero support visual (caption copy):** the pipeline, one line:
`Jira ticket → spec → plan → implementation → review → PR`

_Headline alternatives:_

- **A (locked one-liner, recommended):** "Your AI software team that ships while you sleep." — Matches the canonical positioning and the star-CTA business goal; the sleep line is the owned phrase.
- **B:** "Ticket in, reviewed PR out." — Customer-language quote; sharper for a dev audience arriving from a link that already explains the category. Good as an A/B test variant.
- **C:** "AI writes the code. nightshift runs the other 80%." — Leads with the wedge (process, not code). Strongest for cold visitors who think "another code assistant."

_Primary-CTA alternatives:_

- **A (recommended):** show the two-line command inline with `Copy install command` — the conversion _is_ pasting a command; showing it removes a click.
- **B:** button `Add to Claude Code` linking to install docs — cleaner visually, adds one step.

### Section 2 — Proof bar

Row of four, numbers as proof:

`11 specialized agents` · `10 slash commands` · `install in 60 seconds` · `free · MIT`

_(No customer logos or testimonials — none exist yet. See open decisions.)_

### Section 3 — Problem

**Section header:** You don't lose time writing code. You lose it around the code.

**Body:** The AI already writes the code. What still eats the sprint is the connective tissue: turning a vague ticket into a real spec, a spec into a plan, keeping the plan honest while you implement, then reviewing the result without rubber-stamping your own work.

Coding assistants handle the middle 20%. The other 80% — the process — stays manual, or gets skipped on vibes and shipped unreviewed.

**Sub-points (three):**

- **Vague ticket, no spec.** "Add auth" becomes whatever you remember at 4pm.
- **No enforced lifecycle.** Runbooks exist. Nobody follows them without enforcement.
- **Self-review is a rubber stamp.** Reviewing your own AI output isn't review.

### Section 4 — How it works

**Section header:** One command runs the whole lifecycle

**Body:** Point it at a ticket. It triages the work, then runs each stage in order and closes the loop back to your tracker — spec before plan, plan before code, review before merge, tests as the gate.

**The `/auto` run (labeled steps):**

```
/auto PROJ-142
```

| Step | What runs           | What you get                                                  |
| ---- | ------------------- | ------------------------------------------------------------- |
| 1    | PRD + spec          | The ticket becomes a written spec                             |
| 2    | Plan                | An implementation plan, reviewed before code                  |
| 3    | Implementation      | Code written to the plan, on its own branch                   |
| 4    | QA review           | Independent review by a different agent than the author       |
| 5    | PR + ticket comment | A reviewed PR, with the paper trail linked back to the ticket |

**Fast path note:** Small stories don't need the full ceremony. Stories at or under the lightweight threshold (default ≤3 points) skip straight to implementation.

**Control note:** Want to drive a single stage yourself? Every stage has its own verb: `/spec`, `/plan`, `/impl`, `/review`.

**CTA (secondary, inline):** `See the commands on GitHub`

### Section 5 — The team

**Section header:** A team, not a megaprompt

**Body:** "Do everything" agents hallucinate across roles and leave no trail. nightshift splits the work across 11 agents, each with a tight charter, its own prompt and tools, and a clean handoff to the next. Narrow charters mean fewer hallucinations and an auditable artifact at every stage.

**Role list (copy):** Product Manager · Architect · Tech Lead · Engineers · QA — each a separate agent, each leaving a document behind: PRD, spec, plan, review.

### Section 6 — Why it's different

**Section header:** Why builders choose it

Four value cards:

| Card header                     | Body                                                                                                                                                                                |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The lifecycle is the product    | Spec → plan → implement → review, enforced by the commands and the handoff protocol. Tests are the merge gate. Review is done by a different agent than the one who wrote the code. |
| Generic agents, per-repo config | No hardcoding. Every project fact lives in one `project-context.md`. The same plugin runs a Node monorepo, a Python service, or a mobile app.                                       |
| Issue-tracker native            | It reads the ticket, derives the branch, plan, and PR, and comments the result back to Jira and GitHub.                                                                             |
| Free, open, yours to fork       | Built on open Claude Code primitives, MIT-licensed. Fork it, extend it, swap a role. No lock-in, no paid tier gate.                                                                 |

### Section 7 — Objections / FAQ

**Section header:** Questions builders ask first

**Q. Isn't this just another AI code-writer wrapper?**
No. It's a process engine. The wedge is the SDLC, not the code. Assistants do the middle 20%; nightshift runs the other 80% — spec, plan, review, and the handoffs between them.

**Q. Full ceremony is overkill for a one-line fix.**
`/auto` triages by size. Stories at or under the lightweight threshold (default ≤3 points) skip the spec and plan and go straight to implementation.

**Q. Will it work in my repo and stack?**
The agents are fully generic. Every project-specific fact lives in one `project-context.md` file. The same plugin runs across a Node monorepo, a Python service, or a mobile app — you configure it once per repo.

**Q. What about tool lock-in?**
It's built on open Claude Code primitives and MIT-licensed. Fork it, extend it, or swap out a role. There's no proprietary runtime to get stuck in.

**Q. How do I trust agent output?**
Review is done by a different agent than the author, tests are the merge gate, and every stage leaves an artifact you can read — PRD, spec, plan, review. Nothing merges on vibes.

**Q. What does it cost?**
Nothing. It's free and MIT-licensed. Adoption is the only metric we track.

### Section 8 — Final CTA

**Header:** Put a ticket in tonight. Read a reviewed PR in the morning.

**Body:** Install takes about a minute. Point it at a ticket and watch the spec, plan, code, and review land — with the paper trail linked back where your team already works.

**Install block (repeat of hero):**

```
/plugin marketplace add whimzyLive/nightshift-ai
/plugin install sdlc@nightshift
```

Primary button: `Copy install command`
Secondary button: `Star nightshift on GitHub`

---

## 2b. CRO pass (conversion annotations)

Applied after drafting; the copy deck above already reflects these decisions.

**Quick wins (baked in):**

- **Install command shown inline in the hero, not behind a click.** The conversion action is pasting a command — surfacing it removes a step and matches how this dev audience installs things.
- **CTA copy communicates value, not action.** `Copy install command` and `Star nightshift on GitHub` over generic `Get started` / `Sign up`.
- **Proof bar directly under the hero.** Concrete numbers (11 / 10 / 60 seconds / MIT) do the credibility job that customer logos would, given none exist yet.
- **Install block repeated top and bottom** — primary CTA at both the first and last decision points.

**High-impact / hierarchy:**

- **One primary action throughout** (install), one consistent secondary (star). No competing CTAs.
- **Problem section leads with the customer's own words** ("you lose it around the code") before any product claim.
- **Objection handling given its own section** — the top objection ("another wrapper?") is the exact bounce risk for this category.
- **`/auto` run rendered as a labeled table**, not prose — reads faster, more extractable (feeds AI-SEO).

**Friction removed:**

- No signup, no form, no email gate anywhere — install is a terminal command; the page's only job is to get them to copy it. Keep it that way.
- Free/MIT stated in the proof bar, the value cards, and the FAQ so "what's the catch" is answered before it's asked.

**Test ideas (post-launch, not blocking):**

- Headline A vs C (locked one-liner vs the "other 80%" wedge) for cold traffic.
- Star count as live proof vs omitted (see open decisions).
- Hero visual: static pipeline line vs an animated/asciinema `/auto` run.

---

## 3. JSON-LD (structured data)

`SoftwareApplication` + `Organization` + `FAQPage` under `@graph`. Values trace to the product-marketing doc; no invented metrics.

```json
{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      "@id": "https://github.com/whimzyLive/nightshift-ai#software",
      "name": "nightshift",
      "applicationCategory": "DeveloperApplication",
      "applicationSubCategory": "Claude Code plugin",
      "operatingSystem": "Any (runs inside Claude Code)",
      "description": "A free, MIT-licensed Claude Code plugin that turns one terminal into a full software-delivery team — product manager, architect, tech lead, engineers, and QA. It reads a Jira ticket and ships the spec, plan, code, and review automatically.",
      "url": "https://github.com/whimzyLive/nightshift-ai",
      "downloadUrl": "https://github.com/whimzyLive/nightshift-ai",
      "license": "https://opensource.org/licenses/MIT",
      "isAccessibleForFree": true,
      "offers": {
        "@type": "Offer",
        "price": "0",
        "priceCurrency": "USD"
      },
      "featureList": ["11 specialized agents with tight charters", "10 slash commands", "Enforced lifecycle: spec, plan, implement, review", "Issue-tracker native (Jira and GitHub)", "Generic agents configured per repo via project-context.md", "Independent review by a different agent than the author"],
      "author": { "@id": "https://github.com/whimzyLive#org" },
      "publisher": { "@id": "https://github.com/whimzyLive#org" }
    },
    {
      "@type": "Organization",
      "@id": "https://github.com/whimzyLive#org",
      "name": "whimzyLive",
      "url": "https://github.com/whimzyLive",
      "sameAs": ["https://github.com/whimzyLive/nightshift-ai"]
    },
    {
      "@type": "FAQPage",
      "@id": "https://github.com/whimzyLive/nightshift-ai#faq",
      "mainEntity": [
        {
          "@type": "Question",
          "name": "Isn't nightshift just another AI code-writer wrapper?",
          "acceptedAnswer": {
            "@type": "Answer",
            "text": "No. It's a process engine. The wedge is the SDLC, not the code. Coding assistants handle the middle 20% — writing the code. nightshift runs the other 80%: spec, plan, review, and the handoffs between them."
          }
        },
        {
          "@type": "Question",
          "name": "Is full ceremony overkill for small fixes?",
          "acceptedAnswer": {
            "@type": "Answer",
            "text": "The /auto command triages by size. Stories at or under the lightweight threshold (default 3 points or fewer) skip the spec and plan and go straight to implementation."
          }
        },
        {
          "@type": "Question",
          "name": "Will nightshift work in my repo and stack?",
          "acceptedAnswer": {
            "@type": "Answer",
            "text": "The agents are fully generic. Every project-specific fact lives in one project-context.md file. The same plugin runs across a Node monorepo, a Python service, or a mobile app."
          }
        },
        {
          "@type": "Question",
          "name": "Is there tool or vendor lock-in?",
          "acceptedAnswer": {
            "@type": "Answer",
            "text": "No. nightshift is built on open Claude Code primitives and MIT-licensed. You can fork it, extend it, or swap out a role."
          }
        },
        {
          "@type": "Question",
          "name": "How do I trust the agent output?",
          "acceptedAnswer": {
            "@type": "Answer",
            "text": "Review is done by a different agent than the one that wrote the code, tests are the merge gate, and every stage leaves an artifact you can read: PRD, spec, plan, and review."
          }
        },
        {
          "@type": "Question",
          "name": "What does nightshift cost?",
          "acceptedAnswer": {
            "@type": "Answer",
            "text": "Nothing. nightshift is free and MIT-licensed. There is no paid tier today; adoption is measured in installs and GitHub stars."
          }
        }
      ]
    }
  ]
}
```

**Note for build:** if the landing page ships on its own domain rather than the GitHub repo URL, swap every `url`/`@id` host accordingly and add a `WebSite` node. GitHub repo kept as canonical because that's the current Landing URL token.

**Validation checklist:**

- [ ] Passes Google Rich Results Test (FAQ + SoftwareApplication eligible)
- [ ] `offers.price` = "0" matches the free/MIT claim on the page
- [ ] FAQ JSON-LD text matches the visible Section 7 copy (required — no schema-only content)
- [ ] All URLs fully qualified, absolute

---

## 4. Meta / OG tags

Title 59 chars; description 158 chars. Lowercase `nightshift`.

```html
<!-- Primary meta -->
<title>nightshift — your AI software team that ships while you sleep</title>
<meta name="description" content="nightshift is a free, MIT-licensed Claude Code plugin that runs your whole SDLC. It reads a Jira ticket and ships the spec, plan, code, and review automatically." />
<link rel="canonical" href="https://github.com/whimzyLive/nightshift-ai" />

<!-- Open Graph -->
<meta property="og:type" content="website" />
<meta property="og:site_name" content="nightshift" />
<meta property="og:title" content="Your AI software team that ships while you sleep" />
<meta property="og:description" content="A Claude Code plugin that turns one terminal into a full delivery team — PM, architect, tech lead, engineers, QA. Ticket in, reviewed PR out. Free and MIT." />
<meta property="og:url" content="https://github.com/whimzyLive/nightshift-ai" />
<meta property="og:image" content="https://raw.githubusercontent.com/whimzyLive/nightshift-ai/main/og-image.png" />
<meta property="og:image:alt" content="nightshift pipeline: Jira ticket to spec to plan to implementation to review to PR" />

<!-- Twitter / X -->
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="Your AI software team that ships while you sleep" />
<meta name="twitter:description" content="A Claude Code plugin that runs your whole SDLC — spec, plan, code, review — from one ticket. Free and MIT." />
<meta name="twitter:image" content="https://raw.githubusercontent.com/whimzyLive/nightshift-ai/main/og-image.png" />
<meta name="twitter:image:alt" content="nightshift pipeline: Jira ticket to spec to plan to implementation to review to PR" />
```

**OG image direction (build/design step):** `--night-800` (#0d0d18) background, terracotta `--terra-500` (#d97757) accent, the `Jira ticket → spec → plan → implementation → review → PR` pipeline in JetBrains Mono, wordmark lockup from `.claude/skills/nightshift-design/assets/logo.svg`. The `og-image.png` path is a placeholder until the asset is generated at build — it must be served from a direct-asset URL that returns raw image bytes (not an HTML wrapper page), e.g. `raw.githubusercontent.com` while GitHub is the canonical host; swap to the site's own domain once the page ships there.

---

## 5. llms.txt recommendation

**Placement:** site root, `/llms.txt` (served as `text/plain`). If the landing page ships on its own domain, place it there; while the GitHub repo is canonical, add it as `llms.txt` at the repo root so AI crawlers and coding-agent buyers can read it directly.

**Rationale:** the ICP arrives partly via AI assistants ("best Claude Code plugin for SDLC", "automate Jira ticket to PR"). A short, parseable context file makes nightshift extractable and citable by ChatGPT/Claude/Perplexity without harming Google. No `/pricing.md` needed — the product is free; the free/MIT fact is stated inline below instead.

**Recommended `/llms.txt` content:**

```markdown
# nightshift

> A free, MIT-licensed Claude Code plugin that turns one terminal into a full
> software-delivery team — product manager, architect, tech lead, engineers,
> and QA. It reads a Jira ticket and ships the spec, plan, code, and review
> automatically: Jira ticket → spec → plan → implementation → review → PR.

## What it is

- Category: AI SDLC automation / Claude Code plugin (multi-agent delivery workflow)
- Flagship plugin: `sdlc`. Companion: `gtm`.
- Price: free and open source, MIT-licensed. No paid tier.
- Not a code-writing assistant — a process engine. Assistants do the middle 20%
  (the code); nightshift runs the other 80% (the lifecycle around it).

## Who it's for

- Individual builders and small product teams already using Claude Code.
- The senior dev, tech lead, or founding engineer who owns the workflow.

## How it works

- One command, `/auto <TICKET>`, runs the full lifecycle and comments the
  resulting PR back to the ticket.
- Stages are enforced: spec before plan, plan before code, review before merge,
  tests as the merge gate. Review is done by a different agent than the author.
- Small stories (default ≤3 points) skip straight to implementation.
- 11 specialized agents, 10 slash commands. Configured per repo via one
  `project-context.md` file — the agents themselves are generic.

## Install

/plugin marketplace add whimzyLive/nightshift-ai
/plugin install sdlc@nightshift

## Links

- Repository: https://github.com/whimzyLive/nightshift-ai
- License: MIT
```

**Also for the build:** confirm `robots.txt` allows GPTBot, ClaudeBot, PerplexityBot, and Google-Extended so those engines can cite the page.

---

## 6. Brand tokens (applied from `brand/BRAND_KIT.md`)

Source of truth: `.claude/skills/nightshift-design/` — tokens in `tokens/*.css`, assets in `assets/`, UI kit in `components/`, voice in `references/voice-and-content.md`. Use semantic aliases in components, not raw scale values. Run `npm run validate` in the design-system directory before shipping.

### Identity

| Token                   | Value                                                                                                        |
| ----------------------- | ------------------------------------------------------------------------------------------------------------ |
| Name                    | `nightshift` — always lowercase; reword to avoid sentence-initial capitalization                             |
| Tagline (locked lockup) | `you sleep, it ships` — always lowercase, never substituted                                                  |
| Signature prose phrase  | "ships while you sleep" (prose form of the tagline — used in the hero headline)                              |
| Wordmark                | `.claude/skills/nightshift-design/assets/logo.svg` (dark bg) / `logo-light.svg` (light bg) — never retypeset |
| Moon mark               | `.claude/skills/nightshift-design/assets/logomark.svg` (nav 28px, avatar, favicon-scale)                     |
| Favicon                 | `.claude/skills/nightshift-design/assets/favicon.svg`                                                        |
| Load-bearing glyph      | 🌙 only — no other emoji in body copy                                                                        |

### Color (launch subset — exact values in `tokens/colors.css`)

| Role                          | Token                                       | Hex                               |
| ----------------------------- | ------------------------------------------- | --------------------------------- |
| Page background               | `--night-800`                               | `#0d0d18`                         |
| Deepest void                  | `--night-900`                               | `#08080f`                         |
| Card / surface                | `--night-600`                               | `#1a1a2e`                         |
| Terminal surface              | `--surface-terminal`                        | `#0b0b14`                         |
| Primary text                  | `--moon-100`                                | `#f5f3ef`                         |
| Body text                     | `--moon-200`                                | `#d8d6e0`                         |
| Muted text                    | `--moon-300`                                | `#a9a7bd`                         |
| **Brand accent (terracotta)** | `--terra-500`                               | `#d97757`                         |
| Accent hover / press          | `--terra-400` / `--terra-600`               | `#e58b6f` / `#c2624a`             |
| Links / focus (indigo)        | `--indigo-400` / `--indigo-500`             | `#8b9cf7` / `#7c93f0`             |
| Data / info (cyan)            | `--cyan-400`                                | `#62c4d3`                         |
| Success / warning / danger    | `--green-400` / `--amber-400` / `--red-400` | `#6ec48a` / `#e0a458` / `#e0656f` |

Rules: **one pointing color** — terracotta is the single brand accent, one accent per view; indigo/cyan/semantic colors are functional, not decorative. Components use semantic aliases (`--bg-page`, `--surface-card`, `--accent`, `--text-strong`, …).

### Typography

| Role                                                                                 | Token                                    | Face                                             |
| ------------------------------------------------------------------------------------ | ---------------------------------------- | ------------------------------------------------ |
| Headings & body                                                                      | `--font-sans`                            | Inter — headings sentence case, never Title Case |
| Anything you'd type (commands, agent names, paths, the install block, pipeline line) | `--font-mono`                            | JetBrains Mono                                   |
| Section eyebrows                                                                     | mono `//` prefix, e.g. `// how it works` | JetBrains Mono                                   |

### Per-section token mapping

| Page section       | Treatment                                                                                                                                                                                                                               |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hero               | `--night-800` bg, wordmark lockup (`logo.svg`), headline Inter sentence-case `--moon-100`, install block on `--surface-terminal` in JetBrains Mono, primary CTA `--terra-500` (hover `--terra-400`), pipeline caption mono `--moon-300` |
| Proof bar          | `--night-600` surface, numbers mono `--moon-100`, separators `--moon-300`                                                                                                                                                               |
| Problem            | body `--moon-200`, sub-point leads `--moon-100`, eyebrow `// the other 80%`                                                                                                                                                             |
| How it works       | `/auto` block on `--surface-terminal`, table borders `--night-600`, step numbers `--terra-500`, eyebrow `// how it works`                                                                                                               |
| The team           | agent names in mono (`product-manager`, `qa-engineer`), eyebrow `// the team`                                                                                                                                                           |
| Why it's different | 4 cards on `--surface-card`, card headers `--moon-100`, single terracotta accent reserved for hover/border-active                                                                                                                       |
| FAQ                | questions `--moon-100`, answers `--moon-200`, eyebrow `// questions`                                                                                                                                                                    |
| Final CTA          | mirror hero: terminal install block, `--terra-500` primary button, star button secondary (indigo link treatment or outline)                                                                                                             |

### Voice (enforced, gate-checked)

Technical peer, not marketer. Thesis → mechanism → proof. Numbers as proof, no hype adjectives, no over-claiming ("replaces your team", "powerful", "revolutionary", "next-gen" all banned). Free/open source stated plainly. Signature phrases reused: "ships while you sleep", "a team, not a megaprompt", "generic agents, per-repo config", "the lifecycle is the product", "connective tissue", "spec before plan, plan before code, review before merge, tests as the gate".

---

## Run metadata

- **Copy-review gate:** PASS (2026-07-10) — zero hard-ban violations, zero positioning-discipline violations; project Voice overrides: none (empty section, plugin defaults governed).
- **marketing-council:** not requested (no `--council` flag).
- **CRO `offers` pass:** not triggered — CTA framing assessed strong (copyable command + free/MIT/60-second offer).

## Open copy decisions (founder)

1. **No social proof / testimonials.** Known gap — none exist; numbers proof bar used in their place. Supply an early-adopter quote or launch proof-light?
2. **GitHub star count.** Verified value 4 — deliberately not rendered on-page (low count reads as anti-proof). `Star on GitHub` CTA stays. Show live count once higher?
3. **Canonical URL / domain.** All SEO URLs use the current Landing URL token (GitHub repo). If the Payload `apps/marketing` site gets a dedicated domain, swap canonical, JSON-LD `@id`s, OG `url`, and llms.txt placement at build.
4. **Headline test.** Ship variant A (locked one-liner); variant C ("AI writes the code. nightshift runs the other 80%.") worth A/B testing post-launch.
5. **No cycle-time / review-pass-rate metrics.** Not yet tracked — no efficiency claims made. When dashboards land, they're the strongest proof upgrade.
