<div align="center">

# 🌙 nightshift

### Your AI software team that ships while you sleep.

**A drop-in [Claude Code](https://claude.com/claude-code) plugin that turns one terminal into a full software-delivery team — Product Manager, Architect, Tech Lead, Engineers, and QA — driven straight from your issue tracker.**

`Jira ticket → spec → plan → implementation → review → PR.` Automatically. In any repo.

[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-d97757?logo=anthropic&logoColor=white)](https://code.claude.com/docs/en/plugins)
[![Marketplace](https://img.shields.io/badge/marketplace-nightshift-1a1a2e)](https://github.com/whimzyLive/nightshift-ai)
[![Stars](https://img.shields.io/github/stars/whimzyLive/nightshift-ai?style=social)](https://github.com/whimzyLive/nightshift-ai/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[**Install**](#-install-in-60-seconds) · [**How it works**](#-how-it-works) · [**The team**](#-meet-your-team) · [**Configure**](#-configure-your-repo) · [**Extend**](#-extend-the-agents-to-your-stack) · [**Contribute**](#-contributing)

</div>

---

> ⭐ **If this saves you a sprint, star the repo.** It's how other builders find it.

## The problem

You don't lose time *writing* code. You lose it in the **connective tissue** around it: turning a vague ticket into a real spec, breaking that spec into a plan, keeping the plan honest while you implement, then reviewing it without rubber-stamping your own work.

AI coding assistants are great at the middle 20%. nightshift automates the other 80% — the **process** — by giving Claude Code a team of specialized agents that each own one stage of the lifecycle and hand off cleanly to the next.

## What it is

**nightshift** is a Claude Code plugin marketplace. Its flagship plugin, **`sdlc`**, installs a repo-agnostic software-delivery team:

- **11 specialized agents** — one per role, each with a tight charter and clean handoff protocol.
- **10 slash commands** — the whole lifecycle, one verb at a time: `/spec`, `/plan`, `/impl`, `/review`, plus a one-shot `/auto`.
- **Issue-tracker native** — reads a ticket, derives the branch, the plan path, the PR. Closes the loop back to Jira/GitHub.
- **Zero hardcoding** — every project-specific fact (stack, paths, Jira key, base branch) lives in one config file per repo. The agents are 100% generic. Install once, use everywhere.

It is **not** a wrapper that "writes code for you." It's a process engine that makes a senior team's *discipline* the default — spec before plan, plan before code, review before merge, tests as the gate.

## ⚡ Install in 60 seconds

In any Claude Code session:

```text
/plugin marketplace add whimzyLive/nightshift-ai
/plugin install sdlc@nightshift
```

That's it. The shared workflow skills it depends on ([superpowers](https://github.com/obra/superpowers)) install **automatically** — nightshift declares them as a cross-marketplace dependency, so an existing install is reused and a missing one is pulled in for you. No duplicate copies, no version juggling.

> **Prerequisites:** Claude Code, plus the `acli` (Jira) and `gh` (GitHub) CLIs for the ticket/PR integrations. Both are optional if you only want the spec/plan/impl/review flow locally.

## 🚀 60-second demo

```text
You:           /auto PROJ-142

product-manager      → reads the ticket, writes a PRD (problem, users, acceptance criteria)
solutions-architect  → turns the PRD into a technical spec
tech-lead            → breaks the spec into an ordered, verifiable plan
principal-engineer   → dispatches domain engineers in dependency order
   platform-engineer →   implements, tests, commits on a feature branch
qa-engineer          → reviews against the spec, runs the quality gate, verifies ACs
                     → opens the PR, comments back on the ticket
```

You went from a ticket key to a reviewed PR — with a paper trail at every stage — without leaving the terminal.

> 📹 **[Add a 30-second screencast here]** — the single highest-leverage thing you can do for this README. Show `/auto` running end to end.

## 🧠 How it works

Three ideas do all the heavy lifting:

**1. A team, not a megaprompt.** Each role is a separate agent with its own system prompt, tools, and memory. The Product Manager can't touch infrastructure; the Platform Engineer can't invent acceptance criteria. Narrow charters mean fewer hallucinations and cleaner handoffs — the same reason real teams specialize.

**2. Generic agents, per-repo config.** The agents carry **zero** project specifics. Everything that changes between repos — tech stack, owned paths, Jira project key, base branch, quality-gate commands — lives in a single `.claude/project/project-context.md` the plugin auto-loads every session. Write that one file and the entire team adapts to your codebase.

**3. The lifecycle is the product.** Spec → plan → implement → review isn't a suggestion; it's enforced by the commands and the handoff protocol. Tests are the merge gate. Reviews are done by a *different* agent than the one who wrote the code.

```text
        ┌──────────────── reads .claude/project/project-context.md every session ───────────────┐
        │                                                                                        │
  /spec ─▶ product-manager ─▶ solutions-architect ─▶ tech-lead ─▶ /plan                          │
                                                                    │                            │
                                                                    ▼                            │
  /impl ─▶ principal-engineer ─┬─▶ database-administrator                                        │
                               ├─▶ platform-engineer                                             │
                               ├─▶ web-engineer / mobile-engineer / sync-engineer                │
                               └─▶ qa-engineer ─▶ /review ─▶ PR + ticket update ─────────────────┘
```

## 👥 Meet your team

| Agent | Owns |
| ----- | ---- |
| **product-manager** | Vague idea → PRD with binary acceptance criteria |
| **solutions-architect** | PRD → technical design / spec |
| **scrum-master** | Story slicing, mapping, splitting |
| **tech-lead** | Spec → ordered, verifiable implementation plan |
| **principal-engineer** | Orchestrates the build, dispatches domain agents in dependency order |
| **platform-engineer** | Backend / infrastructure / serverless |
| **web-engineer** | Web UI |
| **mobile-engineer** | Mobile apps |
| **database-administrator** | Schema, migrations, data |
| **sync-engineer** | Offline / sync layer |
| **qa-engineer** | Always-on review → quality gate → AC verification → PR |

Standby roles activate only when your `project-context.md` says your project has them — a backend-only repo never spins up the mobile engineer.

## 🎛️ The commands

| Command | Does |
| ------- | ---- |
| `/auto <TICKET>` | The whole pipeline, end to end |
| `/refine-feature`, `/refine-issue` | Sharpen a raw idea or ticket before work starts |
| `/prd`, `/stories` | Product definition + story breakdown |
| `/spec` | Produce the technical spec |
| `/plan` | Break the spec into an ordered plan |
| `/impl` | Execute the plan with domain agents |
| `/review`, `/review-fix` | Review against the spec, then fix what review found |

## 🔧 Configure your repo

Each consuming repo supplies **one file** — `.claude/project/project-context.md` — declaring its constants. The plugin's SessionStart hook auto-loads it into every session; you never edit your `CLAUDE.md`.

```markdown
# Project Context

| Token            | Value                          |
| ---------------- | ------------------------------ |
| Project name     | acme-api                       |
| Jira project key | ACME                           |
| Base branch      | develop                        |
| Package manager  | pnpm                           |
| Typecheck / Test | pnpm typecheck / pnpm test     |

## Workspace → agent
| Path              | Owner             |
| ----------------- | ----------------- |
| services/api/     | platform-engineer |
| apps/web/         | web-engineer      |
```

That's the whole integration. The agents read this, resolve their owned paths and quality gates from it, and adapt. Repo-agnostic by design — the same plugin runs your Node monorepo, your Python service, and your mobile app.

## 🧩 Extend the agents to your stack

You almost never fork nightshift. The agents are deliberately generic — you teach them your
tech stack from **your own repo**, through two project-tier files plus any skills you write. The
generic agents stay untouched and keep getting upstream updates.

Each domain agent, at startup, does this:

1. reads `.claude/project/project-context.md` (constants, tooling, the workspace→agent ownership table);
2. reads its **override** `.claude/project/agents/<agent>.md` — and **invokes every project skill that file lists, in order, via the Skill tool**, then reads the directory guides it points to.

So extending an agent = **write a skill + name it in the override.** Three steps:

### 1. Add a skill (your stack's know-how)

Drop it in your repo at `.claude/skills/<name>/SKILL.md`:

```markdown
---
name: my-orm
description: How we model entities, write migrations, and query with <your ORM>.
---

When writing data-access code in this project:
- Entities live in `src/db/entities/*.ts`; one file per entity.
- Every migration is generated, never hand-written: `npm run db:generate`.
- Always scope queries by `tenantId`. Never return cross-tenant rows.
```

Skills can be anything an agent should *pull in on demand*: an ORM convention, an API-routing
pattern, a design system, a deployment recipe. Skills from **any** installed plugin work too —
just reference them by name.

### 2. Bind the skill to an agent (the override)

Create `.claude/project/agents/<agent>.md` (e.g. `platform-engineer.md`). This is the contract the
generic agent reads:

```markdown
# Platform Engineer — <your-project> bindings

## Project skills (invoke in order via the Skill tool)
1. my-orm
2. my-api-patterns      # only when touching HTTP routes

## Directory guides (read before coding)
- src/db/CLAUDE.md
- src/api/CLAUDE.md

## Ownership
- owns: src/api/, src/db/
- never: src/web/ (web-engineer)
- runs after: database-administrator · before: web-engineer

## Tech rules
- <Framework + runtime>, TypeScript strict, no `any`, kebab-case files.
- <Any "always do X / never do Y" your codebase enforces.>

## Local dev (tokens from project-context Tooling)
- Build: `<your build cmd>` · Test: `<your test cmd>` · never run cloud deploys.
```

The agent invokes `my-orm` and `my-api-patterns` via the Skill tool at runtime, reads your
directory guides, and confines itself to your owned paths — all without editing the shipped agent.

### 3. Declare ownership + tooling once (project-context)

In `.claude/project/project-context.md`, the **workspace→agent** table is the single source of
truth for who owns what, and the **Tooling** rows define the quality gate every agent runs:

```markdown
## Workspace → agent
| Path       | Owner             |
| ---------- | ----------------- |
| src/api/   | platform-engineer |
| src/web/   | web-engineer      |

## Tooling
| Typecheck | `npm run typecheck` |
| Test      | `npm test`          |
```

### Patterns

- **New tech, existing role** → add a skill + list it in that role's override. (Most common.)
- **Same role, different conventions per repo** → just change the override; the generic agent is reused as-is.
- **Activate a standby role** (mobile, sync, db) → mark it Active in project-context and give it an override.
- **A brand-new role** (e.g. `ml-engineer`) → fork the marketplace, add `agents/ml-engineer.md` to the plugin, and `/plugin marketplace update`. PRs for broadly useful roles are welcome.

> Rule of thumb: **project-specific knowledge → your repo's `.claude/` (skills + overrides + project-context). Generic role behavior → the plugin.** Keep that line clean and upgrades never fight your customizations.

## 💡 Why builders like it

- **Process for free.** The discipline of a senior team, encoded — without writing a runbook nobody follows.
- **Portable.** One install, every repo. Onboard a new project by writing a single config file.
- **Auditable.** Every stage leaves an artifact: a PRD, a spec, a plan, a review. No black box.
- **Composable.** Built on open Claude Code primitives (agents, commands, skills, hooks) — fork it, extend it, swap a role.

## 🗺️ Roadmap

- [ ] GitLab / Linear / Azure DevOps adapters alongside Jira
- [ ] One-command `project-context.md` scaffolder (`/sdlc init`)
- [ ] Additional language/stack starter configs
- [ ] Metrics: cycle-time and review-pass-rate dashboards

Have an idea? [Open an issue](https://github.com/whimzyLive/nightshift-ai/issues) or vote on one.

## 🤝 Contributing

PRs welcome — new agents, commands, stack configs, adapters, and docs. The generic tier is guarded by a portability lint (`tools/portability-lint.sh`) that fails if any project-specific token leaks into the shared plugin. Run it before you push.

## 📣 Spread the word

If nightshift earned a place in your workflow:

- ⭐ **Star the repo** — the single biggest signal for discovery.
- 🐦 Post your `/auto` run (a screen recording beats a thousand words).
- 💬 Tell us what role or adapter you want next.

## License

MIT © [whimzyLive](https://github.com/whimzyLive)

<div align="center">
<sub>Built on <a href="https://claude.com/claude-code">Claude Code</a> · agents, commands, skills, and hooks all the way down.</sub>
</div>
