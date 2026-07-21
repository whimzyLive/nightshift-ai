---
title: 'hono-api'
description: 'Use when building or extending REST APIs with Hono + @hono/zod-openapi. Covers schema-first route declaration with createRoute, feature-grouped composable routers, a class-based service layer behind interfaces, the strategy pattern for multi-event webhooks, typed request validation, and auto-generated OpenAPI docs.'
---

# hono-api

Use when building or extending REST APIs with Hono + @hono/zod-openapi. Covers schema-first route declaration with createRoute, feature-grouped composable routers, a class-based service layer behind interfaces, the strategy pattern for multi-event webhooks, typed request validation, and auto-generated OpenAPI docs.

---

**Source:** `skills/hono-api/SKILL.md`

# Hono REST API — Composable Architecture

A scalable structure for Hono APIs using `@hono/zod-openapi`: routes are schema-first, business
logic lives in a class-based service layer, and the OpenAPI document is generated from the route
definitions — never written by hand.

## Core principle

Routes are **schema-first**: declare the request/response shape with Zod via `createRoute`, then write
the handler. `c.req.valid(...)` returns typed, validated input, and the OpenAPI spec is derived from
the same definitions.

## Folder structure

Group by **feature**, co-locate each route/service with its own schema, and keep one source root:

```
src/
├── app.ts                       # OpenAPIHono root — mounts routers + docs + error handler
├── index.ts                     # runtime entry (server / serverless adapter)
├── routes/
│   └── health/
│       ├── route.ts             # createRoute + handler
│       └── schema.ts            # Zod schemas for this route only
└── services/
    └── orders/
        ├── service.interface.ts # the contract
        ├── service.ts           # class implements the interface
        └── schema.ts            # Zod schemas for this service only
```

Rules:

- **Group by feature** — each route and service gets its own directory; files are `route.ts` /
  `schema.ts` / `service.ts` (no repeated prefix — the directory name gives context).
- **Schema co-location** — a `schema.ts` lives in the same directory as its `route.ts` / `service.ts`.
  Only cross-cutting shared schemas move to a shared location.
- **One source root** — keep a single `src/`; never nest another `src/` inside a feature directory.

## Route + schema pattern

```typescript
// routes/health/schema.ts
import { z } from 'zod';

export const HealthResponseSchema = z.object({
  status: z.literal('ok'),
  uptime: z.number(),
});

export type HealthResponse = z.infer<typeof HealthResponseSchema>;
```

```typescript
// routes/health/route.ts
import { OpenAPIHono, createRoute } from '@hono/zod-openapi';
import { HealthResponseSchema } from './schema';

const healthRoute = createRoute({
  method: 'get',
  path: '/health', // relative — the prefix is added by app.route()
  responses: {
    200: {
      content: { 'application/json': { schema: HealthResponseSchema } },
      description: 'Liveness probe',
    },
  },
});

export const healthRouter = new OpenAPIHono();

healthRouter.openapi(healthRoute, (c) => {
  return c.json({ status: 'ok' as const, uptime: process.uptime() });
});
```

## Service layer — class-based, noun-based, interface-first

Business logic lives in **service classes** grouped by the **noun they talk to** (orders, payments,
notifications) — never by verb. Each noun directory holds `service.interface.ts` (the contract) and
`service.ts` (the `class … implements I<Noun>Service`). Consumers depend on the interface type.

```typescript
// services/orders/service.interface.ts
import type { Order, CreateOrder } from './schema';

export interface IOrderService {
  get(id: string): Promise<Order | null>;
  create(input: CreateOrder): Promise<Order>;
}
```

```typescript
// services/orders/service.ts
import type { IOrderService } from './service.interface';

export class OrderService implements IOrderService {
  async get(id: string): Promise<Order | null> {
    /* ... */ return null;
  }
  async create(input: CreateOrder): Promise<Order> {
    /* ... */
  }
}

// Export a singleton instance — import this (typed as the interface), not the class.
export const orderService = new OrderService();
```

- **Interface first, class implements it** — compile-time enforcement and a clear extension contract.
- **All I/O lives in the service** (DB, queues, outbound HTTP, signature checks) — keep it out of
  routes. Routes stay thin: validate → call a service → serialise the result.
- **Services stay pure of Hono** — no `Context`, no `c`. They take plain inputs and return plain data,
  so they are trivially unit-testable against the interface with a stub.
- Constructor injection of dependencies is fine where it aids testing.

## Multi-event webhooks — strategy pattern

When **one endpoint** receives many event types from a provider, accept all valid events and dispatch
by type. Never expose one endpoint per event, and never grow an `if`/`switch` over event types in the
handler.

**Rule:** one endpoint → one dispatcher → one strategy class per event type, each implementing a
shared interface. A new event is a new strategy class registered in one place; the route and
dispatcher stay untouched.

```typescript
// routes/webhook/strategies/strategy.interface.ts
export interface IEventStrategy<TPayload, TResult> {
  readonly event: string; // matched against the payload's event-type field
  handle(payload: TPayload): Promise<TResult>;
}
```

```typescript
// routes/webhook/strategies/dispatcher.ts
import type { IEventStrategy } from './strategy.interface';
import { NoopStrategy } from './noop.strategy';

export class WebhookDispatcher<TPayload, TResult> {
  private readonly registry = new Map<string, IEventStrategy<TPayload, TResult>>();
  constructor(
    strategies: IEventStrategy<TPayload, TResult>[],
    private readonly fallback: IEventStrategy<TPayload, TResult> = new NoopStrategy(),
    private readonly keyOf: (p: TPayload) => string,
  ) {
    for (const s of strategies) this.registry.set(s.event, s);
  }
  dispatch(payload: TPayload): Promise<TResult> {
    return (this.registry.get(this.keyOf(payload)) ?? this.fallback).handle(payload);
  }
}
```

- **A typed `NoopStrategy` is the default** — a valid event with no registered strategy resolves to it
  and returns **200** (acknowledge, no side effect). Never return 4xx for an event you simply do not
  act on yet — that triggers provider retry storms.
- Strategy classes hold **flow logic only**; all I/O is delegated to the service classes above.
- The route does only: verify the signature on the raw body → parse → `dispatcher.dispatch(payload)`
  → serialise the result as a 200 body.

## Root app — mount routers, docs, error handler

```typescript
// app.ts
import { OpenAPIHono } from '@hono/zod-openapi';
import { HTTPException } from 'hono/http-exception';
import { healthRouter } from './routes/health/route';

export const app = new OpenAPIHono();

app.route('/', healthRouter); // mount feature routers with their prefix

app.doc('/openapi.json', {
  openapi: '3.0.0',
  info: { title: 'API', version: '1.0.0' },
});

app.onError((err, c) => {
  if (err instanceof HTTPException) {
    return c.json({ success: false, message: err.message }, err.status);
  }
  return c.json({ success: false, message: 'Internal Server Error' }, 500);
});
```

Hono is runtime-agnostic. Pick the matching entry adapter, e.g.:

```typescript
// index.ts — Node server
import { serve } from '@hono/node-server';
import { app } from './app';
serve(app);

// index.ts — AWS Lambda
import { handle } from 'hono/aws-lambda';
import { app } from './app';
export const handler = handle(app);
```

## Typed request validation

`c.req.valid(...)` returns typed, Zod-validated input — never parse manually:

```typescript
const route = createRoute({
  method: 'post',
  path: '/orders',
  request: { body: { content: { 'application/json': { schema: CreateOrderSchema } } } },
  responses: {
    201: { content: { 'application/json': { schema: OrderSchema } }, description: 'Created' },
  },
});

router.openapi(route, async (c) => {
  const body = c.req.valid('json'); // typed as CreateOrder
  return c.json(await orderService.create(body), 201);
});
```

## Quick reference

| Task                   | Pattern                                                                                                                   |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------- | --------- |
| New domain             | `routes/<name>/route.ts` + `routes/<name>/schema.ts`; mount in `app.ts`                                                   |
| New route              | `createRoute({})` → `router.openapi(route, handler)`                                                                      |
| Route / service schema | `schema.ts` inside the same feature directory                                                                             |
| New service            | `services/<noun>/service.interface.ts` + `class … implements I<Noun>Service`; export a singleton; group by noun, not verb |
| Multi-event webhook    | One endpoint → `WebhookDispatcher` → one strategy class per event; `NoopStrategy` default                                 |
| Path / query params    | declare in `request` on `createRoute`; read via `c.req.valid('param'                                                      | 'query')` |
| Error                  | `throw new HTTPException(status, { message })`                                                                            |
| OpenAPI                | auto-generated from routes — never hand-write YAML/JSON                                                                   |

## Additional resources

Portable bash scaffolders (coreutils only, never overwrite existing files) live in `scripts/`. Run
them from a consumer project's root:

- `scripts/new-route.sh <name>` — scaffolds `src/routes/<name>/route.ts` + `schema.ts` following the
  route + schema pattern (`createRoute` + `OpenAPIHono` + a co-located Zod schema). Use when adding a
  new feature route; then mount the exported router in `app.ts`.
- `scripts/new-service.sh <noun>` — scaffolds `src/services/<noun>/service.interface.ts` + `service.ts`
  - `schema.ts` following the class-based noun-service pattern (`class <Noun>Service implements
I<Noun>Service`, exported as an interface-typed singleton). Use when adding business logic for a new
    noun, kept out of the routes.

## Common mistakes

| Mistake                                         | Fix                                                             |
| ----------------------------------------------- | --------------------------------------------------------------- |
| Schema defined inside the route file            | Separate `schema.ts` — enables reuse and testing                |
| `c.req.json()` instead of `c.req.valid('json')` | `valid()` returns typed + validated data                        |
| Routes registered directly on the root `app`    | Feature routers + `app.route()` — keeps `app.ts` thin           |
| Hand-writing OpenAPI                            | `createRoute` + `app.doc()` generates it                        |
| Hono imports inside services                    | Services stay pure — no `Context`, no `c`                       |
| Service as loose exported functions             | `class … implements I<Noun>Service` — interface first           |
| Verb-named service directories                  | Name by noun (`services/orders/`, not `services/create-order/`) |
| One endpoint per webhook event type             | Single endpoint + `WebhookDispatcher` keyed on event type       |
| 4xx for an unhandled-but-valid event            | `NoopStrategy` → 200; avoids provider retry storms              |
