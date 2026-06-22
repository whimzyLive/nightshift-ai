# nightshift — voice & content guide

How nightshift writes. Match this in every artifact — headings, body, button labels, alt text, error copy.

## Product context (so copy is accurate)
nightshift is a Claude Code **plugin marketplace**. Flagship plugin `sdlc` installs a repo-agnostic software-delivery team: ~11 specialized agents (one per role) + 10 slash commands that run the lifecycle one verb at a time. A Jira ticket goes in; a reviewed PR comes out, with an auditable artifact at every stage. **Positioning wedge:** not "AI writes code" (commoditized) but **"AI runs your SDLC with a real team's discipline."** Lead with the team-of-agents angle.

Audience: senior developers, engineering leads, indie builders. They live in the terminal and distrust hype.

## Voice rules
- **Technical peer, not marketer.** Confident, dry, specific. Lead with mechanism and proof.
- **Person:** `"you"` for the reader; `"it" / "the agents"` for the product. First person rare, only collective ("we").
- **Casing:**
  - Brand `nightshift` — **always lowercase**, even at sentence start where possible. Never "Nightshift"/"NightShift".
  - Agent + command names lowercase mono: `product-manager`, `/auto`, `qa-engineer`.
  - Headings **sentence case**, never Title Case.
- **Numbers as proof.** "11 specialized agents," "10 slash commands," "the middle 20%," "the other 80%," "install in 60 seconds." Concrete counts beat adjectives.
- **Structure: thesis → mechanism → proof.** State the claim, explain how it works, then show the terminal output. The three-ideas pattern ("A team, not a megaprompt") is signature.
- **Mono for anything you'd type.** Commands, agent names, file paths, branch names, Conventional Commit lines → JetBrains Mono. That's the "terminal texture."

## Signature phrases (reuse, don't dilute)
- "ships while you sleep"
- "a team, not a megaprompt"
- "generic agents, per-repo config"
- "the lifecycle is the product"
- "connective tissue"
- "spec before plan, plan before code, review before merge, tests as the gate"

## Emoji
Sparingly. The **🌙 moon** is the one brand-load-bearing glyph. README section markers (🌙 ⚡ 🧠 👥 🎛️ 🔧) are the upstream exception. In product UI and the design system, prefer the **SVG moon mark** + mono `//` eyebrows over emoji. Never sprinkle emoji through body copy.

## Don't
- Over-claim: "replaces your team," "powerful," "revolutionary," "next-gen."
- Empty intensifiers / hype adjectives — show the `/auto` run instead.
- Title-Case the brand.
- Marketing fluff a senior dev would eye-roll at.

## Micro-copy examples
| Context | ✅ nightshift | ❌ off-brand |
|---|---|---|
| Hero | "Your AI software team that ships while you sleep." | "The most powerful AI coding platform ever." |
| Section eyebrow | `// HOW IT WORKS` | "Amazing Features!" |
| Button | `Install` · `/auto` (mono) | "Get Started Now 🚀" |
| Proof | "11 agents, 10 commands, one `/auto` run." | "Revolutionary automation." |
| Status | `passing` · `pending review` | "All good! 🎉" |
