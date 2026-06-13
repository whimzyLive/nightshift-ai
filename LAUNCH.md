# nightshift — Launch & Distribution Playbook

A practical, sequenced go-to-market plan for making `nightshift-ai` trend. Built around one
principle: **a great demo + the right rooms, repeated.** Tools spread when someone sees a 30-second
clip that makes them think *"that would save me a sprint"* and the link is one click away.

---

## 0. Positioning (lock this first)

Everything below reuses these. Write them once, paste them everywhere.

- **One-liner:** *"Turn Claude Code into a full software-delivery team — PM, architect, engineers, QA — driven from your issue tracker."*
- **Sub-hook:** *"Jira ticket → spec → plan → code → review → PR. Automatically. In any repo."*
- **Who it's for:** developers and small teams already using Claude Code who feel the *process* tax (specs, planning, review), not the typing tax.
- **The wedge:** it's not "AI writes code" (commoditized) — it's **"AI runs your SDLC with a real team's discipline."** Lead with the team-of-agents angle; it's the differentiator.
- **Proof, not adjectives:** never say "powerful/revolutionary." Show the `/auto` run.

---

## 1. Pre-launch checklist (do NOT skip — this is 80% of success)

A launch with no assets dies on arrival. Prepare these before posting anywhere:

- [ ] **A 30–60s screen recording** of `/auto <TICKET>` running end to end. This is the single most important asset. Host on YouTube (unlisted→public) + embed as a GIF in the README.
- [ ] **3–4 screenshots**: the agent handoff in the terminal, a generated spec, a generated plan, the PR it opened.
- [ ] **README polished** (done) with the demo embedded at the top.
- [ ] **A LICENSE file** (MIT) — people won't adopt without it.
- [ ] **`CONTRIBUTING.md`** + a few **"good first issue"** labels — makes the repo look alive.
- [ ] **3–5 seed issues** on the roadmap (adapters, scaffolder) — signals momentum and invites contribution.
- [ ] **A pinned "Show HN / launch" thread draft** for each platform (templates in §4).
- [ ] **Social preview image** set on the GitHub repo (Settings → Social preview) — controls how links unfurl.
- [ ] **Repo topics** added: `claude-code`, `claude-code-plugin`, `ai-agents`, `sdlc`, `developer-tools`, `llm`, `anthropic`, `agentic`.
- [ ] **A short landing section** in README answering "is this safe / what does it touch" — trust removes friction.

---

## 2. Where to publish — the full channel map

Grouped by type. Don't blast all at once; sequence them (§3). ⭐ = highest leverage for this product.

### A. Claude Code / Anthropic ecosystem (start here — warmest audience) ⭐
- **`awesome-claude-code`** and similar curated GitHub lists — submit a PR adding nightshift. (Search GitHub for `awesome-claude-code`, `awesome-claude-code-plugins`, `awesome-claude-skills`.)
- **Anthropic / Claude Developers Discord** — the plugins / share / show-and-tell channels.
- **Claude community plugin-marketplace lists** — get nightshift listed wherever community marketplaces are aggregated.
- **r/ClaudeAI** (Reddit) — the single most on-target subreddit. ⭐
- **Anthropic Developer forum / community** posts.

### B. Developer launch platforms ⭐
- **Hacker News** — `Show HN: nightshift – turn Claude Code into a full SDLC team`. ⭐ (Highest ceiling, highest variance. Post Tue–Thu ~8–10am ET. First comment = your context.)
- **Product Hunt** — schedule a launch day; line up hunters/supporters beforehand. ⭐
- **Lobsters** (`show` tag) — smaller, high-quality dev crowd.
- **Indie Hackers** — "I built…" post + the story.
- **Peerlist Launchpad**, **Uneed**, **BetaList**, **Devhunt**, **Microlaunch** — secondary launch boards; good for sustained backlinks.

### C. Reddit communities (tailor each post, don't cross-post identically) ⭐
- r/ClaudeAI ⭐, r/ChatGPTCoding ⭐, r/devtools, r/programming (strict — lead with substance), r/artificial, r/SaaS, r/SideProject, r/ExperiencedDevs (be humble/technical), r/coolgithubprojects.

### D. Blogging / cross-post platforms (write ONE deep post, syndicate it)
- **Dev.to** ⭐ — dev-native, great reach, canonical-URL friendly.
- **Hashnode** ⭐ — dev blogging, good SEO.
- **Medium** (+ publications like *Better Programming*, *Level Up Coding*).
- **Hacker Noon**.
- **LinkedIn Articles**.
- **Your own blog / Substack** — set the canonical URL, syndicate the rest with `rel=canonical`.
- **freeCodeCamp** (pitch a tutorial-style piece).

### E. Social (build-in-public is the engine) ⭐
- **X / Twitter** ⭐ — demo-video post + a build-in-public thread (how you built a repo-agnostic agent team). Tag relevant accounts; use the clip.
- **LinkedIn** ⭐ — the "I automated my team's SDLC" angle plays very well here.
- **Bluesky** + **Mastodon (fosstodon.org)** — dev-heavy, friendly to OSS.
- **YouTube** (the demo + a 5-min "how it works") and **Shorts/Reels/TikTok** (the 30s clip).
- **Threads**.

### F. Newsletters to pitch (email the curator with the demo link)
- **TLDR** + **TLDR AI** ⭐, **Console.dev** (devtools — perfect fit) ⭐, **Bytes.dev**, **Ben's Bites** / **The Rundown AI**, **Pointer.io**, **Hacker Newsletter**, **Node Weekly / JavaScript Weekly** (if you frame the JS angle), **The Changelog** (news + podcast).

### G. Aggregators / directories (set-and-forget backlinks + SEO)
- **There's An AI For That**, **Futurepedia**, **Future Tools**, **AlternativeTo**, **SaaSHub**, **LibHunt**, **Toolify**, **AI tool directories** generally. Submit once; they keep sending trickle traffic.

### H. Communities / chat (be a member, not a billboard)
- Relevant **Discord/Slack** dev + AI-tooling communities, **Anthropic Discord** (again), language-specific servers where your starter configs apply.

---

## 3. Launch sequence (a 3-week arc)

**Week 0 — Seed (warm, low-risk rooms).**
Ship the README + demo. Post in r/ClaudeAI and the Anthropic Discord. Submit the `awesome-*` PRs. Start a build-in-public thread on X. Goal: first 25–50 stars + early feedback to fix rough edges *before* the big rooms.

**Week 1 — Amplify (owned + earned content).**
Publish the deep-dive blog post (Dev.to canonical → syndicate to Hashnode/Medium/LinkedIn). Post the demo video to YouTube + Shorts. Pitch Console.dev and TLDR AI with the link. Submit to the directories in §G.

**Week 2 — Peak (high-ceiling launches).**
**Product Hunt** launch (pick a Tue/Wed; rally your week-0 supporters in the first 2 hours). Same day or next: **Show HN** on Hacker News. Cross-post tailored versions to r/ChatGPTCoding, r/devtools, Lobsters, Indie Hackers. Be present in comments all day — responsiveness drives ranking.

**Ongoing — Sustain.**
Ship a visible improvement weekly (an adapter, a starter config, the `/sdlc init` scaffolder) and post each as its own mini-update ("nightshift now supports Linear"). Momentum compounds; a repo that ships weekly stays on lists and in feeds.

---

## 4. Copy templates (steal these)

**Hacker News — Show HN**
> **Show HN: nightshift – turn Claude Code into a full SDLC team**
> I kept losing time not to writing code but to the process around it — turning tickets into specs, specs into plans, then reviewing my own work. nightshift is a Claude Code plugin that installs a team of role-specific agents (PM, architect, tech lead, engineers, QA) that run the lifecycle from a Jira ticket to a reviewed PR. The agents are 100% generic; each repo supplies one config file. Demo + repo: [link]. Happy to answer anything about the agent-handoff design.

**Reddit (r/ClaudeAI)**
> **I built a Claude Code plugin that runs my whole SDLC as a team of agents**
> [30s demo gif]. One command, `/auto <ticket>`, and a PM agent writes the PRD, an architect specs it, a tech lead plans it, engineers implement on a branch, and a QA agent reviews + opens the PR. Repo-agnostic — one config file per project. It's MIT, feedback very welcome: [link]

**X / Twitter (thread opener)**
> I gave Claude Code a software team. 🧵
> One terminal → PM, architect, engineers, QA — each a separate agent with its own job.
> `/auto PROJ-142` ↓ [demo video]
> Here's how I made it repo-agnostic so it works in any codebase:

**Newsletter pitch (email)**
> Subject: Tool submission — nightshift (Claude Code → full SDLC team)
> Hi [name], I built an open-source Claude Code plugin that turns it into a role-based software team (spec→plan→impl→review, driven from Jira). 30s demo: [link]. MIT, repo: [link]. Thought it might fit [newsletter]. Happy to write a short blurb in your format.

---

## 5. Metrics to watch

- **GitHub stars / day** (the headline vanity-but-real signal; watch the slope, not the number).
- **Install attempts** — proxy via marketplace-add traffic / clone count / unique visitors (repo Insights).
- **Referrers** in GitHub Insights → doubles down on what's working.
- **Issue/PR opens** — the real adoption signal; a stranger filing an issue > 100 stars.
- **Demo video retention** — if people drop before the payoff, re-cut it.

---

## 6. Do / Don't

**Do**
- Lead with the demo, everywhere.
- Tailor each post to its room; respect each community's rules and tone.
- Reply to every comment on launch day — engagement drives ranking on HN/PH/Reddit.
- Be honest about limits (needs Claude Code; Jira/GitHub CLIs for the integrations).

**Don't**
- Identical copy-paste across subreddits (fast way to get banned).
- Fake metrics, fake reviews, or vote manipulation on PH/HN (also a fast ban).
- Launch on Product Hunt and HN without the demo ready — you get one first impression.
- Over-claim. "Runs your SDLC" is true and strong; "replaces your team" is neither.

---

*Ship the demo first. Everything else is distribution.*
