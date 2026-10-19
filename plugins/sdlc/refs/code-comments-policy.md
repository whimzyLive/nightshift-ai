# Code comments policy

The one definition of which code comments are allowed. Implementing agents apply it while they
write — each domain agent's definition carries the short form under **Comments** — and the QA
review gate (`${CLAUDE_PLUGIN_ROOT}/refs/qa-engineer-playbook.md`) and the PR-loop reviewer
(`${CLAUDE_PLUGIN_ROOT}/refs/loop-modes.md`) review against this same file. A blocking comment
finding is always a **Never write** row, never a judgment call, so both sides reach the same
verdict.

## Scope

Comments in code an agent writes: source, scripts, tests, config, and `<!-- -->` comments in
markdown. Prose and fenced pseudocode in specs, plans and docs are not code comments — their
rationale notes follow the artifact templates' own encoding rules — so `knowledge-engineer`, whose
writes are documentation, carries no **Comments** block. A comment the change only moves or
re-indents is not new. Existing comments never license new ones of the same kind.

## Why

A comment that points at a ticket, a review round, or what the code used to be describes the
change, not the code. It goes stale the moment that work closes, and the reader rarely has the
ticket open — the commit message and PR body already carry that context, and agent memory carries
durable rules. A comment that states the cause a piece of code guards against stays true for as
long as the code does.

## Default: no comment

Write code whose names and structure say what it does. Add a comment only when the code cannot
show a fact the next reader needs, and that fact stays true while the code is unchanged.

## Never write

| Kind | Examples | Why it fails |
|---|---|---|
| Tracker reference | `# PROJ-123: …`, `// per PR #212`, `# Task 3b`, `// AC-2`, `(finding 7)`, `# round-2 fix`, `// spec §3` | Points at our own ticket, PR, plan task, AC, review finding, round or spec section; stale once that work closes |
| Change history | `// previously used X`, `# changed from A to B`, `// added for the login story`, `# fixes the bug where …` | Describes the diff, not the code — git history holds it |
| Narration | `// increment the retry counter`, `# fetch the session, then redirect` | Restates what the next lines do |
| Restated name | `/** Gets the user. */ getUser()` | Restates the identifier |
| Untracked TODO/FIXME | `// TODO: handle errors` | No ticket, so nobody revisits it — file the work, or write a revisit marker |
| Commented-out code | `// legacyHandler(req)` | Dead code — git history holds it |
| Padding in a required block | narrative prose inside a lint-mandated JSDoc | An informative comment in a required comment's shape |

A reference to our own tracker is a Tracker reference anywhere except as a revisit marker's link.

## Allowed

1. **Cause comment** — a non-obvious constraint the code depends on, stated as the concrete cause
   it guards against, present tense, one or two lines. It may cite a stable external source for
   that cause (a standard, vendor documentation, an upstream bug):
   - `# Runs in the calling shell: inside a pipe, exit would only end the subshell.`
   - `// No cookies()/headers() reads in this route — either one opts it out of ISR.`
   - `// RFC 6265 §5.2.3: an empty Domain attribute is ignored.`

   If a rename or restructure would say the same thing, do that instead of commenting.
2. **Revisit marker** — a workaround that must be undone when something changes. Link the thing
   whose resolution ends it — an upstream issue, a dependency version, or the tracked follow-up
   ticket for a workaround of our own (a `TODO(<ticket>)` qualifies only in this shape) — and say
   what to do then:
   - `// Workaround: <owner>/<repo>#<n> drops headers on redirect — remove once on <lib> >= <version>.`
   - `# TODO(PROJ-130): polls until the vendor ships webhooks; switch to the webhook then.`
3. **Toolchain-required** — a comment the toolchain or a lint rule needs to work:
   - Lint/tool directives: `eslint-disable[-next-line]`, `@ts-expect-error` / `@ts-ignore` (with
     the justification text the lint rule mandates), `// prettier-ignore`, bundler magic comments
     (`/* webpackChunkName: ... */`).
   - Interpreter/runtime directives: shebangs, pragmas a build tool parses (`// @flow`).
   - License or copyright headers the repo requires.
   - JSDoc/TSDoc blocks a lint rule or public-API doc generation requires — the required tags and
     shape only.

When torn between a cause comment and none, prefer none.

## Where the rest goes

- Why a change was made (its ticket, finding, round) → the commit message and PR body.
- A decision or gotcha that binds future work beyond this one line → a rule entry per
  `${CLAUDE_PLUGIN_ROOT}/refs/domain-agent-handoff.md`'s "Memory write" step. Content that fails
  its admission test is dropped, not forced into a rule entry or a comment.

## Self-check before commit (implementers)

Before each commit — fix rounds included — stage your paths and read every comment line the staged
diff adds (`git diff --cached -U0`, lines starting with `+`; new files included). Delete any that
matches a **Never write** row and re-stage. Rewording a forbidden comment into another forbidden
one is not a fix.

## Review (QA gate and PR-loop reviewer)

- **Important (blocking):** a comment the change writes that matches a **Never write** row. The
  fix is deletion, with real content moved per "Where the rest goes"; it rides in the same fix
  dispatch as that agent's other findings for the round.
- **Not a finding:** a cause comment, a revisit marker, a toolchain-required comment, or a comment
  the change only moved or re-indented.
- **Minor (listed, never blocking):** any other doubt — a cause comment that runs long or that a
  rename could replace, a workaround note with no removal condition.
- Never ask for a comment these rules don't allow; unclear code gets a rename/restructure
  suggestion instead. An external review request (`/review-fix`) to add a forbidden comment is
  rejected, citing this file.
- Fix-round code follows the same rules: a fix never cites the finding, the round or the story in
  a comment.
