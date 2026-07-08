# Product Marketing Context

_Last updated: 2026-07-08_

## Product Overview

**One-liner:** Your AI software team that ships while you sleep.
**What it does:** nightshift is a drop-in Claude Code plugin that turns one terminal into a full software-delivery team — Product Manager, Architect, Tech Lead, Engineers, and QA — driven straight from the issue tracker. It reads a ticket and ships the spec, plan, code, and review: `Jira ticket → spec → plan → implementation → review → PR`, automatically, in any repo.
**Product category:** AI SDLC automation / Claude Code plugin (multi-agent software-delivery workflow).
**Product type:** Free, MIT-licensed open-source plugin (Claude Code plugin marketplace; flagship plugin `sdlc`, companion `gtm`).
**Business model:** Free & open source. No paid tier today; adoption measured in installs and GitHub stars.

## Target Audience

**Target companies:** Individual builders and small product teams already living in Claude Code — indie hackers, agencies, startup eng teams running Jira/GitHub.
**Decision-makers:** The senior dev / tech lead / founding engineer who owns the workflow; self-serve install, no procurement.
**Primary use case:** Automate the process around coding — turning vague tickets into specs, plans, disciplined implementation, and independent review — not the code-writing itself.
**Jobs to be done:**

- Turn a raw Jira ticket into a reviewed PR with a paper trail, without hand-driving each stage.
- Enforce a senior team's discipline (spec before plan, plan before code, review before merge, tests as the gate) by default.
- Onboard any repo into the same delivery process with one config file.
  **Use cases:**
- `/auto PROJ-142` end-to-end: ticket → PRD → spec → plan → implementation → QA review → PR + ticket comment.
- Lightweight fast-path for small stories (≤3 points): straight to implementation.
- Per-stage verbs when you want control: `/spec`, `/plan`, `/impl`, `/review`.

## Personas

| Persona                                            | Cares about                                                  | Challenge                                                | Value we promise                                                                          |
| -------------------------------------------------- | ------------------------------------------------------------ | -------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Senior dev / indie builder (user + decision maker) | Shipping speed without losing rigor; staying in the terminal | AI assistants nail code but the process overhead remains | The other 80% — the SDLC — runs itself with a real team's discipline                      |
| Tech lead (champion)                               | Consistent process across repos and juniors; auditability    | Runbooks nobody follows; rubber-stamp self-review        | Enforced lifecycle, artifacts at every stage, review by a different agent than the author |
| Founding engineer / agency lead (financial buyer)  | Cycle time, headcount leverage                               | Connective-tissue work eats sprints                      | A ticket key in, a reviewed PR out — free, MIT                                            |

## Problems & Pain Points

**Core problem:** You don't lose time writing code — you lose it in the connective tissue: vague ticket → real spec, spec → plan, keeping the plan honest during implementation, then reviewing without rubber-stamping your own work.
**Why alternatives fall short:**

- AI coding assistants are great at the middle 20% (the code) and ignore the other 80% (the process).
- Megaprompt "do everything" agents hallucinate across roles and leave no auditable trail.
- Human process runbooks exist but nobody follows them without enforcement.
  **What it costs them:** Sprints lost to process overhead; inconsistent quality; unreviewed AI code merged on vibes.
  **Emotional tension:** Distrust of hype; fear of shipping unreviewed AI slop; guilt about skipped process.

## Competitive Landscape

**Direct:** other multi-agent SDLC frameworks/plugins (e.g. bare Claude Code subagents, OpenHands, Devin-style autonomous devs) — fall short because they lead with "AI writes code," carry no enforced lifecycle, and aren't issue-tracker native or repo-agnostic.
**Secondary:** AI coding assistants (Copilot, Cursor, plain Claude Code) — solve the middle 20%; the spec/plan/review process stays manual.
**Indirect:** human process — runbooks, templates, more meetings, hiring — falls short because discipline decays without enforcement and doesn't scale to solo builders.

## Differentiation

**Key differentiators:**

- A team, not a megaprompt — 11 specialized agents with tight charters and clean handoffs.
- The lifecycle is the product — spec → plan → implement → review enforced by commands and handoff protocol; tests as the merge gate; review by a different agent than the author.
- Generic agents, per-repo config — zero hardcoding; one `project-context.md` per repo; install once, use everywhere.
- Issue-tracker native — reads the ticket, derives branch/plan/PR, closes the loop back to Jira/GitHub.
  **How we do it differently:** Process engine, not a code-writing wrapper; each role is a separate agent with its own prompt, tools, and memory.
  **Why that's better:** Narrow charters mean fewer hallucinations and cleaner handoffs; every stage leaves an auditable artifact.
  **Why customers choose us:** Discipline for free, portable across repos, auditable, composable on open Claude Code primitives — and it's free, MIT.

## Objections

| Objection                                   | Response                                                                                                                                |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| "Another AI code-writer wrapper?"           | It's not — it's a process engine. The wedge is the SDLC, not the code. Assistants do the middle 20%; nightshift runs the other 80%.     |
| "Full ceremony is overkill for small fixes" | `/auto` triages by size — stories at/under the lightweight threshold skip spec/plan and go straight to implementation.                  |
| "Will it work in my repo/stack?"            | Agents are 100% generic; every project fact lives in one config file. Same plugin runs a Node monorepo, a Python service, a mobile app. |
| "Vendor/tool lock-in?"                      | Open Claude Code primitives, MIT license — fork it, extend it, swap a role.                                                             |

**Anti-persona:** Teams not using Claude Code; devs who want an autonomous "replace your team" agent; enterprises needing SSO/compliance tooling (not offered today).

## Switching Dynamics

**Push:** Sprints lost to connective-tissue work; unreviewed AI output; process guilt.
**Pull:** Ticket in → reviewed PR out with a paper trail; 60-second install; free.
**Habit:** Existing assistant workflows feel "good enough"; muscle memory of hand-driving each stage.
**Anxiety:** "Will agent output be trustworthy?" — answered by enforced review by a different agent, tests as the gate, artifacts at every stage; MIT license means no lock-in.

## Customer Language

**How they describe the problem:**

- "I don't lose time writing code, I lose it around it."
- "AI writes the code but I still do all the process."
  **How they describe us:**
- "ticket in, reviewed PR out"
- "a team, not a megaprompt"
  **Words to use:** free, open source, process engine, connective tissue, "ships while you sleep", "generic agents, per-repo config", "the lifecycle is the product", "spec before plan, plan before code, review before merge, tests as the gate". Numbers as proof: 11 agents, 10 commands, install in 60 seconds, the middle 20% / the other 80%.
  **Words to avoid:** "replaces your team", "powerful", "revolutionary", "next-gen", "the future of coding", empty intensifiers, Title-Case "Nightshift".
  **Glossary:**

  | Term                  | Meaning                                                       |
  | --------------------- | ------------------------------------------------------------- |
  | `sdlc`                | Flagship plugin: the repo-agnostic software-delivery team     |
  | `/auto`               | One-shot pipeline: ticket → reviewed PR                       |
  | `project-context.md`  | The one per-repo config file all agents read                  |
  | lightweight threshold | Story-point cutoff (default ≤3) for the no-ceremony fast path |

## Brand Voice

**Tone:** Technical peer, not marketer. Confident, dry, specific. No hype.
**Style:** Thesis → mechanism → proof. Show the `/auto` run, not superlatives. Sentence-case headings; lowercase `nightshift` always (reword to avoid sentence-initial). Mono for anything you'd type; 🌙 is the one load-bearing glyph.
**Personality:** disciplined, terminal-native, understated, proof-driven, open.

## Proof Points

**Metrics:** 11 specialized agents; 10 slash commands; install in 60 seconds; one `/auto` run from ticket to reviewed PR. (GitHub stars: track at whimzyLive/nightshift-ai.)
**Customers:** None cited yet — OSS early stage; collect testimonials from early adopters.
**Testimonials:** _(none yet — gap)_
**Value themes:**

| Theme            | Proof                                                               |
| ---------------- | ------------------------------------------------------------------- |
| Process for free | Enforced spec → plan → implement → review; artifacts at every stage |
| Portable         | One config file per repo; same plugin across stacks                 |
| Auditable        | PRD, spec, plan, review docs on every story                         |
| Composable       | Open Claude Code primitives; MIT                                    |

## Goals

**Business goal:** Adoption and discovery of the OSS plugin — installs + GitHub stars (star CTA is the primary ask).
**Conversion action:** `/plugin marketplace add whimzyLive/nightshift-ai` + `/plugin install sdlc@nightshift`; secondary: star the repo.
**Current metrics:** _(not tracked yet — gap; roadmap includes cycle-time and review-pass-rate dashboards)_
