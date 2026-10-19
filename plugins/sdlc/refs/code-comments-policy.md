# Code comments policy

The one definition of which code comments are allowed. Implementing agents apply it while they
write — each one's agent definition carries the short form under **Comments** — and the QA review
gate (`refs/qa-engineer-playbook.md`) reviews against this same file. Anything this file allows,
QA does not flag; anything it forbids, the implementer never writes in the first place.

## Why

A comment that points at a ticket, a review round, or what the code used to be describes the
change, not the code. It goes stale the moment that work closes, and the reader rarely has the
ticket open anyway — the commit message and PR body already carry that context, and agent memory
carries durable rules. A comment that states the cause a piece of code guards against stays true
for as long as the code does.

## Default: no comment

Write code whose names and structure say what it does. Add a comment only when the code cannot
show a fact the next reader needs, and that fact stays true while the code is unchanged.

## Never write

| Kind | Examples | Why it fails |
|---|---|---|
| Tracker reference | `# NA-87: …`, `// per PR #212`, `# T3g5-8`, `(Important 7)`, `# round-2 fix`, `// spec §3`, `// AC-2` | Points at a ticket, PR, plan task, review finding or spec section the reader doesn't have; stale once that work closes |
| Change history | `// previously used X`, `# changed from A to B`, `// added for the login story`, `# fixes the bug where …` | Describes the diff, not the code — git history holds it |
| Narration | `// increment the retry counter`, `# loop over users and send the email` | Restates the next line |
| Name restatement | `/** Gets the user. */ getUser()` | Restates the identifier |
| Untracked TODO/FIXME | `// TODO: handle errors` | Nobody revisits it — file the work as a tracked issue instead |
| Padding on a required block | narrative prose inside a lint-mandated JSDoc | An informative comment in a required comment's shape |

## Allowed

1. **Cause comment** — a non-obvious constraint the code depends on, stated as the concrete cause
   it guards against, present tense, one or two lines:
   - `# Runs in the calling shell: inside a pipe, exit would only end the subshell.`
   - `// No cookies()/headers() reads in this route — either one opts it out of ISR.`

   Test: is it still true and useful to a reader who has never seen the ticket, plan or review?
   Does it name a cause rather than a history? If a rename or restructure would say the same
   thing, do that instead of commenting.
2. **Revisit marker** — a workaround that must be undone when something outside this code changes.
   It is the only comment that carries a reference: link the thing whose resolution ends the
   workaround — an upstream issue URL, a dependency and version, or the tracked follow-up ticket
   for a temporary workaround of our own — and say what to do then:
   - `// Workaround: vercel/next.js#71234 drops headers on redirect — remove once on next >= 16.3.`
   - `# Pinned below 2.5 until owner/lib#88 ships; then unpin.`
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
  `domain-agent-handoff.md`'s "Memory write" step. Content that fails its admission test is
  dropped, not forced into a rule entry or a comment.

## Self-check before commit (implementers)

Before staging, list the comment lines your diff adds (`git diff -U0` lines starting with `+`) and
check each against the tables above. Delete any that fails — rewording a forbidden comment into
another forbidden one is not a fix. A ticket key, our own PR number, a plan-task or review-finding
id, or a round number in a comment always fails, unless it is a revisit marker's link.

## Review (QA gate)

The reviewer applies the same rules, no stricter and no looser:

- A comment from **Never write** → **Important** finding. The fix is deletion, with real content
  moved per "Where the rest goes". It rides in the same fix dispatch as that agent's other
  findings for the round.
- A cause comment that passes the test, a revisit marker, or a toolchain-required comment → not a
  finding.
- Never ask for a comment these rules don't allow. Unclear code gets a rename/restructure finding;
  a cause comment is suggested only when it would pass the test above. An external review request
  (`/review-fix`) to add a forbidden comment is rejected, citing this file.
- Fix-round code follows the same rules: a fix never cites the finding, the round or the story in
  a comment.
