---
title: 'Error reference'
description: 'Error-handling behaviour aggregated from Error Handling sections across commands, agents, and refs.'
related-adrs: []
---

# Error reference

Error-handling behaviour aggregated from Error Handling sections across commands, agents, and refs.

---

## ai-enablement-engineer / /sdlc:analyze

**Source:** `plugins/sdlc/refs/analyze-protocol.md#error-handling`

## Error handling

Canonical error-handling table for both the `ai-enablement-engineer` agent and the `/sdlc:analyze`
command — defined exactly once here; each references this anchor instead of restating the rows.

| Scenario                                                                                                                                        | Behavior                                                                                                                                      |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Repo not opted in / `project-context.md` missing or malformed table (agent not Active — see [Active (definition)](#ownership-resolution-rules)) | **STOP** — report-only: "repo not opted in or project-context unreadable — run `/sdlc:init`." Write nothing. Do not scan.                     |
| Scan finds no drift/gaps/conflicts                                                                                                              | Report "no drift detected" and exit cleanly.                                                                                                  |
| Apply attempted without human confirmation                                                                                                      | Refuse — confirmation is mandatory (never auto-apply).                                                                                        |
| Apply target outside resolved write-scope                                                                                                       | Refuse and abort; print the offending path(s); make no writes (AC-5).                                                                         |
| Memory conflict with no human decision (deferred)                                                                                               | Report only; reset nothing.                                                                                                                   |
| Cross-agent memory write attempted outside the two named exceptions (see [Memory-ownership exceptions](#memory-ownership-exceptions))           | Refuse — a reset must be human-arbitrated (Exception 1) and a distill deletion must be founder-gated (Exception 2); anything else is refused. |
| `find-skills` / `skill-creator` unavailable or offline                                                                                          | Degrade gracefully — skip the skill-suggestion step, still emit structural drift; note the skip.                                              |
| `find-skills` install/update commands would run                                                                                                 | Refuse — see [Skill usage guardrails](#skill-usage-guardrails); surfacing/suggesting only.                                                    |
| `raise-pr.sh` fails during standalone apply                                                                                                     | Surface the failure; leave branch + local commit for manual recovery; do not retry silently.                                                  |

---

## gtm docs-auditor

**Source:** `plugins/gtm/agents/docs-auditor.md#error-handling`

## Error Handling

| Scenario                                                                                                                                               | Behaviour                                                                                        | Outcome                                                 |
| ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------- |
| Corpus resolves to zero files                                                                                                                          | Return empty `findings` immediately (step 1) — no rubric pass, no PR work                        | Clean no-op, no PR                                      |
| Audit finds no issues                                                                                                                                  | Return `findings: []`, `prs: []`                                                                 | Clean no-op — no PR opened (AC-4)                       |
| `--dry-run` passed                                                                                                                                     | Audit and return findings; skip step 5 entirely                                                  | Report-only                                             |
| A finding is already covered by an existing open `gtm/docs-audit/*` PR                                                                                 | Drop it before grouping (step 3); never recommended in a new PR                                  | No duplicate recommendation                             |
| A group's branch slug matches an existing open `gtm/docs-audit/*` PR                                                                                   | Skip opening a PR for that group (step 4, defense-in-depth); note it in the prose summary        | No duplicate PR                                         |
| A remote branch already exists for a group slug (from a closed-unmerged, or undeleted-merged, PR — never an open one, step 4 already caught that case) | Force-push with lease to reuse it (step 5.4); note it in the prose summary                       | Findings re-proposed, no push-failure cascade           |
| Finding groups exceed `--max-prs`                                                                                                                      | Open up to the cap; list the remainder's slugs in `deferredGroups`                               | Partial, reported                                       |
| `gh`/`git` not authenticated, or push rejected for any other reason                                                                                    | Stop the PR-opening loop; return the findings collected so far plus the git/gh error             | Findings reported, PRs failed — surfaced, not swallowed |
| `ai-seo` or `content-strategy` skill unavailable at dispatch                                                                                           | Degrade: audit with the remaining skill + the rubric alone; flag the missing skill in the return | Degraded audit, non-fatal                               |
