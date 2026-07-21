---
title: 'electrodb'
description: 'Use when defining DynamoDB entities, modeling indexes, or writing queries/mutations with the ElectroDB ORM. Covers entity schema, access patterns, CRUD operations, update expressions, and single-table design patterns.'
---

# electrodb

Use when defining DynamoDB entities, modeling indexes, or writing queries/mutations with the ElectroDB ORM. Covers entity schema, access patterns, CRUD operations, update expressions, and single-table design patterns.

---

**Source:** `skills/electrodb/SKILL.md`

# ElectroDB

TypeScript-first DynamoDB ORM. Manages composite key composition, enforces attribute types, and generates safe DocumentClient params. No raw `DynamoDBClient` calls.

## Installation

```bash
npm install electrodb @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb
```

## Entity Definition

```typescript
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { Entity } from 'electrodb';

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const Task = new Entity(
  {
    model: {
      entity: 'task', // item type namespace
      service: 'taskapp', // application namespace
      version: '1',
    },
    attributes: {
      taskId: { type: 'string', required: true, default: () => crypto.randomUUID() },
      projectId: { type: 'string', required: true },
      employeeId: { type: 'string', required: true },
      status: { type: ['pending', 'active', 'done'] as const, required: true },
      description: { type: 'string' },
      ttl: { type: 'number' }, // epoch seconds for DynamoDB TTL
      createdAt: { type: 'string', readOnly: true, default: () => new Date().toISOString() },
      updatedAt: { type: 'string', watch: '*', set: () => new Date().toISOString() },
    },
    indexes: {
      // Table index (no `index` property = primary table index)
      primary: {
        pk: { field: 'pk', composite: ['taskId'] },
        sk: { field: 'sk', composite: ['projectId'] },
      },
      // GSI — reference by logical name, not DynamoDB index name
      byProject: {
        index: 'gsi1pk-gsi1sk-index',
        pk: { field: 'gsi1pk', composite: ['projectId'] },
        sk: { field: 'gsi1sk', composite: ['employeeId', 'taskId'] },
      },
    },
  },
  { table: process.env.TABLE_NAME!, client },
);
```

## Schema Quick Reference

### Attribute options

| Option       | Description                                                                          |
| ------------ | ------------------------------------------------------------------------------------ |
| `type`       | `"string"` `"number"` `"boolean"` `"list"` `"map"` `"set"` or enum array `["a","b"]` |
| `required`   | Throw on put/create if missing                                                       |
| `default`    | Static value or `() => value` factory                                                |
| `readOnly`   | Cannot be changed after creation                                                     |
| `watch: "*"` | Re-run `set` on every update (useful for `updatedAt`)                                |
| `validate`   | Regex or `(val) => boolean`                                                          |

### model fields

| Field           | Purpose                                                             |
| --------------- | ------------------------------------------------------------------- |
| `model.entity`  | Namespaces items on the table; prevents cross-entity key collisions |
| `model.service` | Groups entities into a Service for cross-entity queries             |
| `model.version` | Bumping changes key format — migrate existing items first           |

## Index Design

```typescript
indexes: {
  // Primary (table index) — no `index` property
  primary: {
    pk: { field: "pk", composite: ["tenantId"] },
    sk: { field: "sk", composite: ["entityId", "createdAt"] },
  },
  // GSI
  byStatus: {
    index: "gsi1pk-gsi1sk-index",
    pk: { field: "gsi1pk", composite: ["tenantId", "status"] },
    sk: { field: "gsi1sk", composite: ["createdAt"] },
  },
  // LSI (same pk field as table index)
  byDate: {
    index: "lsi1-index",
    pk: { field: "pk", composite: ["tenantId"] },
    sk: { field: "lsi1sk", composite: ["createdAt"] },
  },
}
```

**Key composition rule:** composite array order is hierarchical — you can query on a prefix but not skip attributes. `["a","b","c"]` supports queries on `a` or `a+b` or `a+b+c`, never `b` alone.

## CRUD Operations

All operations are lazy — chain methods build the expression, then call `.go()` to execute or `.params()` to inspect the raw DocumentClient params.

### put (full overwrite)

```typescript
const { data } = await Task.put({
  taskId: 't-001',
  projectId: 'proj-x',
  employeeId: 'emp-42',
  status: 'pending',
}).go();
```

### create (fails if item exists)

```typescript
await Task.create({ taskId, projectId, employeeId, status: 'pending' }).go();
```

### get

```typescript
const { data } = await Task.get({ taskId: 't-001', projectId: 'proj-x' }).go();
// data is null if not found
```

### delete

```typescript
await Task.delete({ taskId: 't-001', projectId: 'proj-x' }).go();
```

### update

```typescript
// Chain operations
await Task.update({ taskId, projectId }).set({ status: 'active', description: 'started' }).go();

// data() for type-safe complex updates
await Task.update({ taskId, projectId })
  .data((a, o) => {
    o.set(a.status, 'done');
    o.remove(a.description);
    o.add(a.retryCount, 1); // increment number
    o.append(a.log, ['step complete']); // append to list
  })
  .go();
```

### patch (update + fails if item missing)

```typescript
await Task.patch({ taskId, projectId }).set({ status: 'done' }).go();
```

## Queries

```typescript
// By primary index — pk composite only
const { data } = await Task.query.primary({ taskId: 't-001' }).go();

// By GSI — filter sk with begins/between/gte/lte
const { data } = await Task.query.byProject({ projectId: 'proj-x' }).begins({ employeeId: 'emp-' }).go();

// Sort descending, limit, paginate
const { data, cursor } = await Task.query.byProject({ projectId: 'proj-x' }).go({ order: 'desc', limit: 20 });

// Next page
const { data: page2 } = await Task.query.byProject({ projectId: 'proj-x' }).go({ cursor });
```

### Sort key operations

| Method                               | DynamoDB equivalent |
| ------------------------------------ | ------------------- |
| `.begins({ sk: "val" })`             | `begins_with`       |
| `.between({ sk: "a" }, { sk: "z" })` | `BETWEEN`           |
| `.gte({ sk: "val" })`                | `>= val`            |
| `.gt({ sk: "val" })`                 | `> val`             |
| `.lte({ sk: "val" })`                | `<= val`            |
| `.lt({ sk: "val" })`                 | `< val`             |

### Filter (post-query)

```typescript
const { data } = await Task.query.byProject({ projectId })
  .where((attr, op) => op.eq(attr.status, "pending"))
  .go();

// Multiple conditions
  .where((attr, op) => `${op.eq(attr.status, "pending")} AND ${op.gt(attr.ttl, 0)}`)
```

## Conditional Writes

```typescript
// Conditional update — fail if condition not met
await Task.update({ taskId, projectId })
  .set({ status: 'done' })
  .where((attr, op) => op.eq(attr.status, 'active'))
  .go();
```

## Execution Options

```typescript
// Inspect params without executing
const params = Task.get({ taskId, projectId }).params();

// Override table at runtime
await Task.get({ taskId, projectId }).go({ table: 'other-table' });

// Include pk/sk in response (stripped by default)
await Task.get({ taskId, projectId }).go({ data: 'includeKeys' });

// Consistent read
await Task.get({ taskId, projectId }).go({ consistent: true });

// Project specific attributes
await Task.get({ taskId, projectId }).go({ attributes: ['status', 'createdAt'] });
```

## Single-Table Design Patterns

**One table, generic key names** — ElectroDB namespaces items by `model.entity` automatically. Items from different entities on the same table never collide.

**TTL** — declare as `{ type: "number" }` attribute, enable TTL on the field in DynamoDB console/CDK. Set epoch-seconds value at write time.

```typescript
const ttl = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 7; // 7 days
await Task.put({ ...attrs, ttl }).go();
```

**Service** — group multiple Entity objects for cross-entity queries:

```typescript
import { Service } from 'electrodb';
const AppService = new Service({ Task, Employee });
// AppService.collections.<collectionName>(...).go()
```

## Common Mistakes

| Mistake                                   | Fix                                                           |
| ----------------------------------------- | ------------------------------------------------------------- |
| Querying a partial composite pk           | All pk composites required; sk composites are optional prefix |
| Using `update` on non-existent item       | Use `patch` to get `ConditionalCheckFailed` or `upsert`       |
| Forgetting `.go()`                        | Expressions are lazy — nothing executes without `.go()`       |
| Raw `DynamoDBClient` for DynamoDB ops     | Always use entity methods; raw client bypasses type safety    |
| Bumping `model.version` without migration | Changes key format — old items become invisible               |
| `set` on a `readOnly` attribute           | Throws at runtime; set defaults only via `default`            |

## Additional resources

- `scripts/new-entity.sh <EntityName>` — scaffolds `src/entities/<entity-name>.entity.ts` with a ready-to-edit `new Entity({...})` skeleton (model namespace, `createdAt`/`updatedAt`/`ttl` attributes, a primary `pk`/`sk` composite index, and one GSI). Derives a kebab-case filename and a PascalCase export from the argument, and never overwrites an existing file. Use it to start a new entity instead of hand-copying the boilerplate above.
