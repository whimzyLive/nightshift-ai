---
name: writing-specs
description: Use when producing a technical design spec for a feature or Jira story. Enforces consistent spec structure covering data model, API surface, permissions, PowerSync sync rules, and web/mobile UI. Run before writing-plans.
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

Entity extends: `BaseEntity` OR `BaseProjectEntity` — state explicitly which and why.

### Modified Entities

[Which existing entity, which fields added/removed/changed — one row per change]

### Relationships

[Text ERD — explicit cardinality]

- Organisation (1) → (many) [Entity] via organisation_id
- [Entity] (1) → (many) [ChildEntity] via [entity]\_id

## API Surface

### New Endpoints

| Method | Path          | Factory          | Description      |
| ------ | ------------- | ---------------- | ---------------- |
| GET    | /[entity]     | ApiRoute         | List all for org |
| POST   | /[entity]     | ApiRouteWithUser | Create           |
| GET    | /[entity]/:id | ApiRoute         | Get by ID        |
| PATCH  | /[entity]/:id | ApiRouteWithUser | Update           |
| DELETE | /[entity]/:id | ApiRouteWithUser | Soft delete      |

Route factory options — pick exactly one per endpoint:

- `ApiRoute` — authenticated, org context required
- `ApiRouteWithUser` — authenticated, full user object resolved
- `PublicApiRoute` — no auth (QR lookups, public read)

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

| Role                 | List       | Get        | Create | Update | Delete |
| -------------------- | ---------- | ---------- | ------ | ------ | ------ |
| fire_safety_engineer | ✓ own org  | ✓ own org  | ✓      | ✓ own  | ✗      |
| inspector            | ✓ assigned | ✓ assigned | ✗      | ✗      | ✗      |
| company_admin        | ✓ org      | ✓ org      | ✓      | ✓      | ✓      |

Role names MUST come from `packages/auth-rules/` — never invent. Run:

```bash
ls packages/auth-rules/src/permissions/
```

## Backend Implementation

**SST stack:** `stacks/apis/<domain>-api.stack.ts` — state exact filename.

**Application layer:**

```
src/application/<domain>/
  implementations/
    get-<entity>.impl.ts
    create-<entity>.impl.ts
    update-<entity>.impl.ts
    delete-<entity>.impl.ts
  mappers/
    <entity>.mapper.ts
  dtos/
    create-<entity>.dto.ts
    update-<entity>.dto.ts
    <entity>.response.dto.ts
```

**Handlers:** `src/handlers/<domain>/` — thin Lambda entry points, one per operation.

**Auth-rules:** `packages/auth-rules/permissions/<domain>.ts` — list exact permission keys to add.

## Web UI (omit section if not web-scoped)

**Pages:**
| Route | File | Description |
|-------|------|-------------|
| /[domain] | src/pages/[domain]/index.tsx | List view |
| /[domain]/[id] | src/pages/[domain]/[id].tsx | Detail view |

**Components:** `src/component/<domain>/` — list names and responsibilities.

**Data hooks:** `src/hooks/use[Entity].ts` — TanStack Query, one per operation.

**State:** Zustand changes in `src/store/` — list which stores change and why.

**Route permissions:** `src/config/route-permission-config/<domain>.ts` — which roles can access which routes.

## Mobile UI (omit section if not mobile-scoped)

**Screens:**
| Route | File | Description |
|-------|------|-------------|
| /(app)/[domain] | app/(app)/[domain]/index.tsx | List screen |
| /(app)/[domain]/[id] | app/(app)/[domain]/[id].tsx | Detail screen |

**Online reads:** REST via `APIProvider` — same endpoints as Web UI.

**Offline reads:** PowerSync SQL hook at `src/powersync/hooks/use[Entity].ts`

```typescript
// REQUIRED pattern — always filter by organisationId via JOIN to projects
const results = usePowerSyncQuery(
  `SELECT e.* FROM [entity] e
   JOIN projects p ON e.project_id = p.id
   WHERE p.owner_id = ?`,
  [organisationId],
);
```

**Offline writes:** Transaction builders needed in `packages/powersync/src/powersync-client/`:

- `create-[entity]-transaction.ts`
- `update-[entity]-transaction.ts`
- `delete-[entity]-transaction.ts` (if applicable)

## PowerSync Sync (omit section if no offline mobile required)

**New table in `config/sync-config.yaml`:**

```yaml
bucket_definitions:
  by_org:
    data:
      - SELECT * FROM [table_name] WHERE organisation_id = bucket.org_id
```

**Staff user filter:** REQUIRED — bucket scoping alone is insufficient. Mobile hook MUST JOIN to `projects.ownerId`. (See Mobile UI section above.)

**Transaction builders:** list each one needed, what it uploads to, and which API endpoint it calls.

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

## Project-Specific Rules

### Entity rules
- `BaseEntity` — use for standalone domain entities (id, createdAt, updatedAt, soft-delete)
- `BaseProjectEntity` — use for project-scoped entities (adds projectId + subProjectId FKs)
- Never say "add a column" — say "add field to entity + generate migration"
- All entities in `packages/database/src/entity/<entity-name>.entity.ts`

### Route factory rules
- `ApiRoute` — when you need org context but not the full user object
- `ApiRouteWithUser` — when the handler needs `user.id` or `user.roles` (creates, auditable mutations)
- `PublicApiRoute` — ONLY for genuinely public endpoints (QR code lookups, public reports)
- Never use raw Lambda handlers — always wrap with a factory

### PowerSync rules
- Any entity visible offline on mobile **must** have a PowerSync section
- Staff users over-sync — bucket scoping alone is NOT sufficient
- Every offline read hook must JOIN to `projects.ownerId` to filter by org
- Never specify `src/schema.ts` edits — it is generated by `pnpm powersync:typegen`

### Role names
Always derive from `packages/auth-rules/` — never invent. Common roles:
`fire_safety_engineer`, `inspector`, `company_admin`, `project_manager`, `manufacturer`

---

## Self-Review Checklist (run before saving)

- [ ] No TBDs — every open question has a concrete answer OR a flagged decision with a suggested default
- [ ] Every new endpoint has a row in the Permissions table
- [ ] Every mobile offline entity has a PowerSync section with the organisationId JOIN pattern
- [ ] Entity relationships state exact cardinality (1:1, 1:N, M:N)
- [ ] Route factory stated for every endpoint (ApiRoute / ApiRouteWithUser / PublicApiRoute)
- [ ] All TypeScript interfaces fully typed — no `any`
- [ ] Spec says WHAT to build — no HOW (no line-by-line implementation instructions)
- [ ] Web / Mobile / PowerSync sections omitted if not applicable to this story
- [ ] `BaseEntity` vs `BaseProjectEntity` choice stated and justified

---

## Anti-Patterns

| Anti-pattern | Fix |
|---|---|
| "Add a column to the table" | "Add field `x: string` to `[Entity]` entity + generate migration" |
| Inventing a role name | Check `packages/auth-rules/permissions/` first |
| Missing organisationId JOIN in mobile hook | Always join to `projects.owner_id` |
| Editing `src/schema.ts` in the spec | Never — it's generated; spec the `sync-config.yaml` change instead |
| `any` in TypeScript interfaces | Fully type every field |
| TBD without a suggested default | Add "Suggested default: X" so impl can proceed |
| Spec contains implementation code | Move to agent instructions, not spec |
| PowerSync section absent for mobile offline entity | Add the section — sync-engineer needs it |
```
