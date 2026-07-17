---
name: writing-specs
description: Use when producing a technical design spec for a feature or Jira story. Enforces consistent spec structure covering data model, API surface, permissions, offline-sync rules where applicable, and web/mobile UI. Run before writing-plans.
---

# writing-specs — Technical Spec

**Core principle:** A spec says WHAT to build — not HOW to implement it line by line. Every section must be concrete enough that an implementation agent can execute without asking questions.

**Announce at start:** "I'm using the writing-specs skill to produce this spec."

## When to Use

- Before any implementation planning (`writing-plans` consumes this output)
- When given a Jira story key or a product feature doc
- When requirements exist but no technical design has been written

## Output File

Save to: `docs/superpowers/specs/<STORY-KEY>.md` — the Jira story key is the entire filename (e.g. `docs/superpowers/specs/CER-2037.md`). The key is globally unique, so any agent can derive this path without a Jira lookup.

Commit on branch `spec/<STORY-KEY>`. Raise PR titled `docs(spec): <STORY-KEY> <story summary>`.

After the PR is merged, comment on the story as a human-readable breadcrumb:

```bash
acli jira workitem comment add <STORY-KEY> \
  --body "Spec: docs/superpowers/specs/<STORY-KEY>.md | PR: <PR_URL>"
```

This comment is for human reference only — other agents derive the path from the story key directly, not from this comment.

**Guard:** If you did not successfully fetch the Jira ticket before calling this skill, STOP and return to fetch it first. Never generate spec content from repository files alone.

---

## Spec Template

````markdown
# [Feature Name] — Technical Spec

**Story:** [JIRA-KEY — link or key]
**Feature:** [link to docs/features/*.md if available]
**Date:** YYYY-MM-DD

## Overview

[What this builds and why — 2 sentences max. No implementation detail.]

## Data Model

### New Entities

| Field | Type | Nullable | Default           | Notes |
| ----- | ---- | -------- | ----------------- | ----- |
| id    | uuid | No       | gen_random_uuid() | PK    |
| ...   | ...  | ...      | ...               | ...   |

Entity base class: choose the correct base class per the project's entity/ORM conventions (see project-context) — state explicitly which and why.

### Modified Entities

[Which existing entity, which fields added/removed/changed — one row per change]

### Relationships

[Text ERD — explicit cardinality]

- Organisation (1) → (many) [Entity] via organisation_id
- [Entity] (1) → (many) [ChildEntity] via [entity]\_id

## API Surface

### New Endpoints

| Method | Path          | Auth/Route Type | Description      |
| ------ | ------------- | --------------- | ---------------- |
| GET    | /[entity]     | [auth type]     | List all for org |
| POST   | /[entity]     | [auth type]     | Create           |
| GET    | /[entity]/:id | [auth type]     | Get by ID        |
| PATCH  | /[entity]/:id | [auth type]     | Update           |
| DELETE | /[entity]/:id | [auth type]     | Soft delete      |

Auth/route type — state exactly one per endpoint, using the project's route/auth conventions (see project-context). Distinguish at minimum:

- authenticated, tenant/org context required
- authenticated, full user object resolved (for creates and auditable mutations)
- public, no auth (only for genuinely public endpoints)

### Request / Response Shapes

```typescript
// POST /[entity]
interface Create[Entity]Body {
  field: string;        // required
  optionalField?: string;
}

interface [Entity]Response {
  id: string;
  field: string;
  createdAt: string;
}
```
````

All TypeScript interfaces must be fully typed. No `any`.

### Permissions

| Role     | List       | Get        | Create | Update | Delete |
| -------- | ---------- | ---------- | ------ | ------ | ------ |
| [role-1] | ✓ own org  | ✓ own org  | ✓      | ✓ own  | ✗      |
| [role-2] | ✓ assigned | ✓ assigned | ✗      | ✗      | ✗      |
| [role-3] | ✓ org      | ✓ org      | ✓      | ✓      | ✓      |

Derive role/permission names from the project's permission source (see project-context) — never invent. Locate that source and enumerate the actual roles before filling this table.

## Backend Implementation

**API / infra layer:** the project's API/infra definition (see the project-context workspace→path table) — state the exact file.

**Application layer:** state the exact files this introduces, following the project's layering conventions (implementations, mappers, DTOs, or the project's equivalents), one per operation.

**Handlers / entry points:** the project's request entry points — thin, one per operation; state exact paths.

**Permissions:** the project's permission source (see project-context) — list the exact permission keys to add.

## Web UI (omit section if not web-scoped)

**Pages:**
| Route | File | Description |
|-------|------|-------------|
| /[domain] | src/pages/[domain]/index.tsx | List view |
| /[domain]/[id] | src/pages/[domain]/[id].tsx | Detail view |

**Components:** the project's web component location (see project-context) — list names and responsibilities.

**Data hooks:** the project's server-data fetching layer (per the web stack in project-context) — list the data hooks/queries needed, one per operation.

**State:** client state changes (per the project's web stack in project-context) — list which stores/slices change and why.

**Route permissions:** the project's route-permission config (see project-context) — which roles can access which routes.

## Mobile UI (omit section if not mobile-scoped)

**Screens:**
| Route | File | Description |
|-------|------|-------------|
| /(app)/[domain] | app/(app)/[domain]/index.tsx | List screen |
| /(app)/[domain]/[id] | app/(app)/[domain]/[id].tsx | Detail screen |

**Online reads:** REST via the project's API client — same endpoints as Web UI.

**Offline reads:** if the project uses offline sync (see project-context), state the read hook/location and the data it exposes. Every offline read MUST apply a tenant/org-scoped filter so a device only ever sees its own tenant's data (e.g. a JOIN or WHERE constraint on the owning tenant/org id) — describe the exact scoping filter for this entity.

**Offline writes:** if the project uses offline sync, list the offline write/transaction builders needed (one per mutating operation) and state their location per the project's sync layer (see project-context).

## Offline Sync (omit section entirely if the project has no offline sync — see project-context)

If the project uses offline sync, the spec MUST cover:

- **Which entities sync** — list every entity that must be available offline.
- **Scoping / tenant-isolation filter** — the rule that limits each device's synced data to its own tenant/org. State it explicitly per entity. Bucket/partition scoping in the sync config alone is often insufficient — the read path must also enforce a tenant/org-scoped filter (see Offline reads above).
- **Read hooks** — where offline reads live and what each exposes.
- **Write hooks / transaction builders** — list each one needed, what it uploads to, and which API endpoint it calls.

Define these using the project's offline-sync technology and config location (see project-context); state the exact files.

## Error Handling

| Scenario                | Behaviour                    | HTTP Status |
| ----------------------- | ---------------------------- | ----------- |
| [Entity] not found      | Return 404                   | 404         |
| Unauthorised role       | Return 403                   | 403         |
| Validation failure      | Return 400 with field errors | 400         |
| [Domain-specific error] | [behaviour]                  | [status]    |

**Offline behaviour:** [what happens if user submits offline write while disconnected — does it queue, fail, or show an error?]

## Out of Scope

- [Thing that sounds related but is NOT in this spec]
- [Future enhancement explicitly excluded]

## Open Questions

[Any decision still needed — each must have a suggested default so implementation can proceed]

- [ ] [Question] — Suggested default: [answer]

```

---

## Project-Specific Rules (resolve from project-context)

### Entity rules
- Choose the correct entity base class per the project's conventions (see project-context) — standalone vs tenant/project-scoped — and state why.
- Never say "add a column" — say "add field to entity + generate migration".
- State the exact entity file using the project's entity/ORM layer (see the project-context workspace→path table).

### Route / auth rules
- State the exact auth/route type per endpoint using the project's conventions (authenticated with tenant/org context; authenticated with full user object for creates and auditable mutations; public only when genuinely public).
- Never leave a raw, unwrapped handler — always use the project's standard route/auth wrapper.

### Offline sync rules (only if the project uses offline sync — see project-context)
- Any entity visible offline **must** have an Offline Sync section.
- Devices over-sync — partition/bucket scoping alone is NOT sufficient.
- Every offline read must enforce a tenant/org-scoped filter (see Offline reads).
- Never specify edits to a generated sync schema/types file — spec the sync-config/rule change instead; the schema is regenerated by the project's typegen step.

### Role names
Always derive from the project's permission source (see project-context) — never invent. Enumerate the actual roles before writing the Permissions table.

---

## Self-Review Checklist (run before saving)

- [ ] No TBDs — every open question has a concrete answer OR a flagged decision with a suggested default
- [ ] Every new endpoint has a row in the Permissions table
- [ ] Every offline-synced entity has an Offline Sync section with an explicit tenant/org-scoped filter (only if the project uses offline sync)
- [ ] Entity relationships state exact cardinality (1:1, 1:N, M:N)
- [ ] Auth/route type stated for every endpoint, using the project's conventions
- [ ] All TypeScript interfaces fully typed — no `any`
- [ ] Spec says WHAT to build — no HOW (no line-by-line implementation instructions)
- [ ] Web / Mobile / Offline Sync sections omitted if not applicable to this story
- [ ] Entity base class choice stated and justified per the project's conventions

---

## Anti-Patterns

| Anti-pattern | Fix |
|---|---|
| "Add a column to the table" | "Add field `x: string` to `[Entity]` entity + generate migration" |
| Inventing a role name | Check the project's permission source first (see project-context) |
| Missing tenant/org-scoped filter in an offline read | Always enforce a tenant/org-scoped filter on every offline read |
| Editing a generated sync schema/types file in the spec | Never — it's generated; spec the sync-config/rule change instead |
| `any` in TypeScript interfaces | Fully type every field |
| TBD without a suggested default | Add "Suggested default: X" so impl can proceed |
| Spec contains implementation code | Move to agent instructions, not spec |
| Offline Sync section absent for an offline-synced entity | Add the section — the sync implementer needs it |
```
