<div align="center">

# 🌙 nightshift

## Your AI software team that ships while you sleep.

**A drop-in [Claude Code](https://claude.com/claude-code) plugin that turns one terminal into a full software-delivery team — Product Manager, Architect, Tech Lead, Engineers, and QA — driven straight from your issue tracker.**

`Jira ticket → spec → plan → implementation → review → PR.` Automatically. In any repo.

[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-d97757?logo=anthropic&logoColor=white)](https://code.claude.com/docs/en/plugins)
[![Marketplace](https://img.shields.io/badge/marketplace-nightshift-1a1a2e)](https://github.com/whimzyLive/nightshift-ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[![⭐ Star this repo](https://img.shields.io/github/stars/whimzyLive/nightshift-ai?style=for-the-badge&label=%E2%AD%90%20Star%20this%20repo&labelColor=0d0d18&color=d97757)](https://github.com/whimzyLive/nightshift-ai)

[**Install**](#-install-in-60-seconds) · [**How it works**](#-how-it-works) · [**The team**](#-meet-your-team) · [**Configure**](#-configure-your-repo) · [**Extend**](#-extend-the-agents-to-your-stack) · [**FAQ**](#-faq) · [**Contribute**](#-contributing)

</div>

---

> ⭐ **If this saves you a sprint, star the repo.** It's how other builders find it.

## The problem

You don't lose time _writing_ code. You lose it in the **connective tissue** around it: turning a vague ticket into a real spec, breaking that spec into a plan, keeping the plan honest while you implement, then reviewing it without rubber-stamping your own work.

AI coding assistants are great at the middle 20%. nightshift automates the other 80% — the **process** — by giving Claude Code a team of specialized agents that each own one stage of the lifecycle and hand off cleanly to the next.

## What it is

**nightshift** is a Claude Code plugin marketplace. Its flagship plugin, **`sdlc`**, installs a repo-agnostic software-delivery team:

- **A full team of specialized agents** — one per role, each with a tight charter and clean handoff protocol.
- **The whole lifecycle as slash commands** — one verb at a time: `/spec`, `/plan`, `/impl`, `/review`, plus a one-shot `/auto`.
- **Issue-tracker native** — reads a ticket, derives the branch, the plan path, the PR. Closes the loop back to Jira/GitHub.
- **Zero hardcoding** — every project-specific fact (stack, paths, Jira key, base branch) lives in one config file per repo. The agents are 100% generic. Install once, use everywhere.

It is **not** a wrapper that "writes code for you." It's a process engine that makes a senior team's _discipline_ the default — spec before plan, plan before code, review before merge, tests as the gate.

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

> **Complexity routing.** `/auto` triages every story by size first. A **small** story (at/under the
> configurable lightweight threshold, default ≤3 points) takes the **fast-path: straight to
> implementation — no spec, no plan doc, no review gate** (tasks are derived inline from the ticket).
> The full spec → plan → review-gate ceremony shown above is reserved for **larger** stories. Raise a
> story's points above the threshold if you want the full treatment.

> 📹 **[Add a 30-second screencast here]** — the single highest-leverage thing you can do for this README. Show `/auto` running end to end.

## 🧠 How it works

Three ideas do all the heavy lifting:

**1. A team, not a megaprompt.** Each role is a separate agent with its own system prompt, tools, and memory. The Product Manager can't touch infrastructure; the Platform Engineer can't invent acceptance criteria. Narrow charters mean fewer hallucinations and cleaner handoffs — the same reason real teams specialize.

**2. Generic agents, per-repo config.** The agents carry **zero** project specifics. Everything that changes between repos — tech stack, owned paths, Jira project key, base branch, quality-gate commands — lives in a single `.claude/project/project-context.md` the plugin auto-loads every session. Write that one file and the entire team adapts to your codebase.

**3. The lifecycle is the product.** Spec → plan → implement → review isn't a suggestion; it's enforced by the commands and the handoff protocol. Tests are the merge gate. Reviews are done by a _different_ agent than the one who wrote the code.

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

Each stage of the lifecycle is owned by a separate agent with its own charter and a clean handoff to the next — from the Product Manager who turns a ticket into a PRD, through the Solutions Architect, Tech Lead, and domain Engineers (platform, web, mobile, database, sync), to the always-on QA Engineer that gates the merge. Standby roles activate only when your `project-context.md` says your project has them — a backend-only repo never spins up the mobile engineer.

📖 **Every agent and its charter, always current → [`docs/reference/agents/`](docs/reference/agents/)** — generated from the plugin sources, so the roster never drifts as roles are added.

## 🎛️ The commands

Run one verb at a time — `/spec`, `/plan`, `/impl`, `/review` — or the whole pipeline end to end with `/auto`. Onboard a repo with `/init`, sharpen raw tickets with `/refine-issue`, and break epics down with `/prd` and `/stories`.

📖 **Full command list with usage, always current → [`docs/reference/commands/`](docs/reference/commands/)** — generated from the command sources, so a newly added command shows up automatically and this README never advertises a stale set.

## 🔧 Configure your repo

Each consuming repo supplies **one file** — `.claude/project/project-context.md` — declaring its constants. The plugin's SessionStart hook auto-loads it into every session; you never edit your `CLAUDE.md`.

> **Onboarding a fresh repo?** Run `/init` — it checks the `gh`/`acli` prerequisites, walks you through Jira auth, and scaffolds `project-context.md` plus your active agents' override files interactively. The manual template below is what it produces.

```markdown
# Project Context

| Token            | Value                      |
| ---------------- | -------------------------- |
| Project name     | acme-api                   |
| Jira project key | ACME                       |
| Base branch      | develop                    |
| Package manager  | pnpm                       |
| Typecheck / Test | pnpm typecheck / pnpm test |

## Workspace → agent

| Path            | Owner             |
| --------------- | ----------------- |
| services/api/   | platform-engineer |
| apps/marketing/ | web-engineer      |
```

That's the whole integration. The agents read this, resolve their owned paths and quality gates from it, and adapt. Repo-agnostic by design — the same plugin runs your Node monorepo, your Python service, and your mobile app.

## 🧩 Extend the agents to your stack

You almost never fork nightshift. The agents are generic; you teach them your stack from **your own
repo** — no edits to the shipped plugin, so upstream updates never fight your customizations. In short:

1. **Add a skill** — your stack's know-how in `.claude/skills/<name>/SKILL.md` (an ORM convention, a routing pattern, a deploy recipe…).
2. **Bind it to a role** — list it in that agent's override `.claude/project/agents/<agent>.md`; the agent invokes it via the Skill tool at runtime.
3. **Declare ownership + tooling once** — the workspace→agent table and quality-gate commands in `.claude/project/project-context.md`.

> **Rule of thumb:** project-specific knowledge → your repo's `.claude/`; generic role behavior → the plugin.

📖 **Full walkthrough with copy-paste templates → [EXTENDING.md](EXTENDING.md).**

## 💡 Why builders like it

- **Process for free.** The discipline of a senior team, encoded — without writing a runbook nobody follows.
- **Portable.** One install, every repo. Onboard a new project by writing a single config file.
- **Auditable.** Every stage leaves an artifact: a PRD, a spec, a plan, a review. No black box.
- **Composable.** Built on open Claude Code primitives (agents, commands, skills, hooks) — fork it, extend it, swap a role.

## ❓ FAQ

**Does nightshift write code for me?**
No. nightshift is a process engine, not a "writes code for you" wrapper. It enforces the discipline around the code — spec before plan, plan before code, review before merge — with tests as the merge gate and a _different_ agent reviewing the work than the one who wrote it.

**What do I need to install it?**
Claude Code, plus the `acli` (Jira) and `gh` (GitHub) CLIs for the ticket and PR integrations. Both CLIs are optional if you only want the local spec → plan → implement → review flow without issue-tracker sync.

**How much does it cost?**
nightshift is free and MIT-licensed. Install it, fork it, extend it, and use it in any repo — commercial or otherwise — at no cost.

**Do I have to configure every agent for my stack?**
No. The agents are 100% generic. Every project-specific fact — stack, owned paths, Jira key, base branch, quality-gate commands — lives in one `.claude/project/project-context.md` per repo. Write that single file and the whole team adapts.

**Does every ticket go through the full spec-plan-review ceremony?**
No. `/auto` triages each story by size first. A story at or under the lightweight threshold (default ≤3 points) goes straight to implementation; the full spec → plan → review-gate flow is reserved for larger stories. Raise a story's points to opt it into the full treatment.

**Do I have to fork nightshift to extend it?**
Almost never. You teach the generic agents your stack from your own repo's `.claude/` directory — add a skill, bind it to a role, and declare ownership once. Because you never edit the shipped plugin, upstream updates never fight your customizations.

## 🗺️ Roadmap

- [x] One-command `project-context.md` scaffolder (`/sdlc:init`)
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
