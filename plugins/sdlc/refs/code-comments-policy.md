# Code comments policy — no informative/explanatory comments

Single source of truth for the "no informative/explanatory code comments" rule. Every active
domain agent's project override (`.claude/project/agents/<agent>.md`) and the QA review gate
(`refs/qa-engineer-playbook.md`) reference this file rather than restating the rule — see
`domain-agent-handoff.md`'s "Memory write" step for where the displaced content belongs.

## Why

This project's SDLC already captures evolving, non-obvious context at the agent-memory level
(`.claude/memories/agents/<agent>.md`) — a record that is actively kept current across stories.
A code comment that narrates or explains carries the same kind of information through a second,
uncoordinated channel: it has no update discipline of its own, drifts out of sync with the code
around it, and can end up silently disagreeing with what memory says. One durable, current record
beats two that can diverge.

## The rule

Do not add informative or explanatory comments to code you write — a comment whose job is to
narrate what the code does, explain why a decision was made, or restate something already
knowable from reading the code and its names. If a decision, gotcha, workaround-rationale, or
subtle invariant is genuinely worth preserving, it belongs in your agent memory file, not inline
in the source (see "Where the content goes instead" below).

**Forbidden — informative/explanatory:**

- Narrating what the next line/block does in prose (`// increment the retry counter`,
  `// loop over users and send the welcome email`).
- Explaining **why** a design or architecture choice was made, a workaround exists, or a subtle
  invariant holds — durable rationale like this is exactly what agent memory is for.
- Restating a function or variable name in sentence form.
- A loose `TODO`/`FIXME` that isn't tracked anywhere else — if the work is real, file it as a
  tracked issue instead of leaving it as a comment nobody revisits.

**Allowed — required by language or lint convention (not a comment you're choosing to add, but
one the toolchain or a lint rule requires to function correctly):**

- Lint/tool directives: `eslint-disable[-next-line]`, `@ts-expect-error` / `@ts-ignore` (with
  whatever justification text the lint rule itself mandates), `// prettier-ignore`, bundler magic
  comments (e.g. `/* webpackChunkName: ... */`).
- Interpreter/runtime directives: shebangs (`#!/usr/bin/env ...`), pragma comments a build tool
  parses (e.g. `// @flow`).
- License or copyright headers mandated by repo/legal policy.
- JSDoc/TSDoc blocks where a lint rule or public-API doc generation genuinely requires them — only
  the required tags/shape; don't pad a required block with extra narrative prose beyond what the
  rule demands (that padding is an informative comment wearing a JSDoc costume).

When in doubt: if removing the comment would make a linter, type-checker, or build step fail (or
strip a license the repo requires), it's required — keep it. If removing it only makes the code
slightly less narrated, it's informative — don't add it; move any real content to memory instead.

## Where the content goes instead

Anything a comment would have explained that's actually worth keeping — a non-obvious decision, a
workaround and its reason, a gotcha future work would otherwise re-discover the hard way — goes in
your agent memory file (`.claude/memories/agents/<agent>.md`), appended per
`domain-agent-handoff.md`'s "Memory write" step, not left inline in the diff.

## Enforcement

1. **Authoring.** Every active domain agent's project override states this rule and points here
   (see `.claude/project/agents/<agent>.md`) rather than restating it — this is the single shared
   location every override references (do not copy this rule's text into an override). The generic
   plugin agent definitions (`plugins/sdlc/agents/*.md`) defer to this file the same way, for every
   agent whose "Conventions" section used to carry its own inline comment guidance — so there is
   exactly one place (this file) either layer can disagree with, not two.
2. **Review gate.** The QA Engineer review loop (`refs/qa-engineer-playbook.md` Step 1 dispatch
   and Step 2 severity) flags any new informative/explanatory comment a PR diff introduces: the
   finding requests the comment be removed and, if it captured real context, that the context be
   moved to the introducing agent's memory file instead. This is an **Important** finding — the
   loop does not return `clean` (and no PR is created) while one is still open.
