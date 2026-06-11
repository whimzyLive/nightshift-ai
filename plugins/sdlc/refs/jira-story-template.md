# Jira Story Template

Canonical story format. Both `/stories` (Epic decomposition) and `/refine-issue` (triage/refine) produce stories using this exact template. Never vary the structure — consistency lets the team scan stories predictably.

For project-specific user roles, read `.claude/project/project-context.md`.

## ⚠️ Formatting rule — always use ADF JSON

**Never write descriptions as Markdown.** `acli --description-file` treats `.md` files as plain text — Markdown symbols (`**`, `- [ ]`, etc.) render as raw characters in Jira.

Always write descriptions as Atlassian Document Format (ADF) JSON. See **`${CLAUDE_PLUGIN_ROOT}/refs/jira-adf.md`** for the full node reference, mark types, and copy-paste templates for both Epic and Story descriptions.

## Story description format

Write the description using this block structure (verbatim section headers):

```
**As a** [specific role — see .claude/project/project-context.md for this project's user roles]
**I want to** [specific action the user takes]
**So that** [business outcome or value delivered]

**Context**
[1–2 sentences explaining WHY this story exists and how it fits the broader feature]

**Acceptance Criteria**
- [ ] [Specific, testable — binary: done or not done]
- [ ] [Specific, testable]
- [ ] [Specific, testable]

**Out of Scope**
- [What this story explicitly does NOT cover — prevents scope creep]

**Dependencies**
- [Story titles or keys that must complete first, or "None"]
```

## Story summary (title) format

```
[Verb]-oriented, ≤8 words — e.g. "Add email notification for failed payments"
```

Do not include role or surface in summary if it makes it longer than 8 words — put that in the description.

## Sizing guidance

| Story type | Story Points |
|---|---|
| Read-only view (single surface) | 2 |
| Read-only view (multiple surfaces) | 3 |
| CRUD with simple form (single surface) | 3 |
| CRUD with validation + permissions (single surface) | 5 |
| CRUD (multiple surfaces, with integration) | 8 |
| Complex workflow with multiple states | 8 |
| New domain entity + full CRUD (all applicable surfaces) | 13 |

**Flag anything estimated >8 points for splitting before creating in Jira.**

## Decomposition rules

**One story = one vertical slice.** A vertical slice covers every layer required to deliver one complete user-verifiable outcome. Include only the layers the story actually needs — but never split a single user outcome across multiple stories by layer or surface.

Split only at these boundaries:

| Boundary | Rule |
|---|---|
| Role | Different user roles are separate stories |
| Workflow state | Different workflow states that are independently demoable are separate stories |
| CRUD layer | Read/list stories separate from create/edit only when each is a complete, independently demoable outcome |

**Do NOT split by layer or domain:**
- API + UI for the same user flow = one story
- "Backend story" + "frontend story" for the same outcome = wrong
- Infrastructure + feature for the same outcome = one story

**Never create stories for:**
- Internal refactors with no user-visible change
- Sub-steps that belong inside another story as subtasks
- "Setup" or "infrastructure" work without a specific, demoable deliverable
- Areas where the feature doc has unresolved open questions — flag and stop

## Acceptance Criteria rules

- Each AC must be binary: either done or not done — no partial states
- Each AC must be independently testable by a QA or product person
- Minimum 3 ACs per story; maximum 6 — if you need more, split the story
- AC should describe WHAT is verifiable, not HOW it is implemented

## Authoring quality

Format is necessary but not sufficient — a story that fills the template can still be low quality. Apply these checks to every story.

**"As a" — specific persona, not generic.**
- ❌ "As a user" (no persona clarity; different users have different needs)
- ✅ "As a trial user", "As a paid subscriber", "As an admin" — use a real role from `.claude/project/project-context.md`

**"I want to" — a user action, not a feature you build.**
- ❌ "As a user, I want a login button" (names the UI element, not the goal)
- ✅ "As a trial user, I want to log in with Google" (the action the user takes)

**"So that" — real motivation, not a restatement of the action.**
- ❌ "I want to click save, so that I can save my work" (just repeats the action)
- ✅ "…so that I don't lose progress if the page crashes" (the actual outcome they care about)

**Acceptance Criteria — measurable, not vibes.**
- ❌ "Then the experience is better" / "Then it's faster" (unverifiable)
- ✅ "Then the page loads in under 2 seconds" / "Then a success confirmation is shown"

**Not a disguised tech task.** If the story delivers no user-visible outcome (e.g. "refactor the API", "upgrade the library"), it is an engineering task, not a story — flag it, do not force it into this template.

**Too big = split.** Signs a story is oversized: it covers multiple distinct outcomes, multiple roles, or needs more than 6 ACs. Split it (see `user-story-splitting`) before creating — never ship the oversized story.
