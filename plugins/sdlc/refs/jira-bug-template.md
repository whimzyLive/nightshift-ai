# Jira Bug Template (Agile Bug Template)

Canonical **bug** format — parallel to `${CLAUDE_PLUGIN_ROOT}/refs/jira-story-template.md`, but for
defect tickets (`issuetype == Bug`). `scrum-master` produces/normalises Bugs using this exact 7-section
structure in **Mode 2 (Triage/refine, via `/refine-issue`)** and gates against it in **Mode 3
(Auto-Assess, via `/auto` Step 1)**. A Bug has **no Mike-Cohn user-story structure** (no "As a / I
want / So that", no `taskList` acceptance criteria) — do not force the story template onto it.

For project-specific environment/role context, read `.claude/project/project-context.md`.

## ⚠️ Formatting rule — always use ADF JSON

**Never write descriptions as Markdown.** `acli --description-file` treats `.md` files as plain text.
Always render the description as Atlassian Document Format (ADF) JSON — see the **Bug description
template** in `${CLAUDE_PLUGIN_ROOT}/refs/jira-adf.md` (headings + ordered/bullet lists, NOT the
user-story `taskList`).

## The 7 sections (verbatim order)

A well-formed bug has these seven sections, in this order:

1. **Summary / Title** — short, descriptive; include the platform/environment, e.g.
   `[iOS] Cart checkout button unresponsive`.
2. **Environment** — OS, device, browser/app version.
3. **Steps to Reproduce** — a numbered, explicit action list.
4. **Actual Result** — a neutral statement of what currently happens.
5. **Expected Result** — a clear, testable, neutral statement of what should happen.
6. **Severity / Impact** — importance level + the affected audience.
7. **Attachments / Proof** — screenshots, recordings, or error logs.

## Required vs best-effort gate rules

The quality gate (Mode 3) and the rewrite (Mode 2) apply these classes. **REQUIRED** sections must be
present (synthesised from available input if missing — their absence triages the ticket);
**best-effort** sections never hard-block — record them as "not provided" when absent.

| # | Section | Gate class | Behaviour when absent |
| - | ------- | ---------- | --------------------- |
| 1 | Summary / Title | **REQUIRED** | must be synthesised → `QUALITY=triaged` |
| 3 | Steps to Reproduce | **REQUIRED** | `QUALITY=triaged` |
| 4 | Actual Result | **REQUIRED** | `QUALITY=triaged` |
| 5 | Expected Result | **REQUIRED** | `QUALITY=triaged` |
| 6 | Severity / Impact | **REQUIRED** | `QUALITY=triaged` |
| 2 | Environment | best-effort | recorded as "not provided" — never hard-blocks |
| 7 | Attachments / Proof | best-effort | recorded as "not provided" — never hard-blocks |

- **Well-formed bug** (all 5 REQUIRED sections present) → `QUALITY=ok`.
- **Malformed bug** (any REQUIRED section missing) → triage in-place into this template, synthesising
  the missing REQUIRED sections from whatever input exists → `QUALITY=triaged`.
- Best-effort sections (Environment, Attachments/Proof) absent → render "not provided"; they do **not**
  gate `QUALITY=ok`.

## Bug summary (title) format

```
[<platform/env>] <short symptom> — e.g. "[Android] Push notifications never arrive after re-login"
```

Keep it a symptom, not a guessed cause. Include the platform/environment in brackets when known.

## Severity / Impact guidance

State an importance level and who is affected — e.g. "Critical — all iOS users cannot check out" /
"Minor — cosmetic misalignment on the settings page for tablet widths". Severity drives prioritisation;
do not invent a level the report does not support — if unknown, record what impact *is* evidenced and
mark the level as needing confirmation.

## What a bug is NOT

- Not a feature request or enhancement — those use the story template.
- Not a disguised tech task with no observable defect.
- The completion contract for a bug is a **failing→passing regression test** (the systematic-debugging
  defect path), not Mike-Cohn acceptance criteria.
