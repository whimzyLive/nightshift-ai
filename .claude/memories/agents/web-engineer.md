## 2026-07-12 — Story NA-34 — home you-decide-how-its-built control section (single state-machine island)

**Learnings:**

- The design's raw JSX markup (`nightshift Landing.dc.html` L404-532) nests
  the ENTIRE section 8 body — triage card, gate strip, and the 1120px-wide
  comparison grid — inside one `max-width:760px` wrapper, which is an
  authoring inconsistency in the mock itself (a 1120px child cannot actually
  render wider than its 760px parent in a browser). Followed the plan's own
  explicit override text instead ("centered header column max-width: 760px,
  comparison grid max-width: 1120px" — i.e. two separate width scopes), and
  restructured as an outer div at max-width 1120 containing a nested
  max-width-760 header block, mirroring `team-preview.tsx`'s own two-tier
  width pattern. When a plan explicitly resolves an ambiguity/bug present in
  the raw design markup, follow the plan's resolution, not the mock's literal
  nesting.
- `Eyebrow` (`packages/ui`) already prepends the mono `//` glyph itself
  (`<span aria-hidden>{'//'}</span>{children}`) — every existing call site
  (`team-preview.tsx`, `day-night-workflow.tsx`) passes the bare label with
  no `//` prefix (`<Eyebrow>04 · the team</Eyebrow>`). A plan/spec that
  writes the JSX literally as `<Eyebrow>// 06 · control</Eyebrow>` is
  describing the rendered _result_, not the literal children to pass — doing
  so verbatim would double the slashes. Always check the actual component
  source before trusting a plan's inline JSX snippet for a wrapper that adds
  its own chrome.
- Extending a shared `packages/ui` primitive (`CtaButton`) with new
  `size`/`variant` props for one story's needs: split the previously-monolithic
  class string into `BASE_CLASSES` (layout/transition/focus, size- and
  variant-independent) + `SIZE_CLASSES`/`VARIANT_CLASSES` records, destructure
  `size`/`variant` out of props _before_ spreading `...rest` onto the DOM
  element (otherwise they'd leak as invalid `size`/`variant` HTML attributes
  on `<a>`/`<button>`), and keep both defaults (`size:'md'`, `variant:'primary'`)
  matching the pre-existing single treatment exactly so every call site with
  zero new props (`hero.tsx`, `day-night-workflow.tsx`, etc.) renders
  byte-identical classes — confirmed via the full `ui` suite staying green
  with no test changes needed for existing consumers.
- A `useReducer` gate-machine driven by `useEffect`s keyed on the resulting
  state (not imperative `setState`-inside-`setTimeout`-inside-`setState`
  chains, which is what the design's own class-component source does with
  instance fields) is the correct hooks translation: one effect keyed on
  `[ticketType, storyPts, thresh, approvalMode]` dispatches a pure
  `RESTART_GATE` (satisfies AC4 — every config setter this story exposes is
  itself one of those four fields, so there's no separate "restart" call
  needed anywhere else); a second effect keyed on `[gI, gS]` owns the
  working→awaiting timer; a third keyed on the full gate-relevant tuple owns
  the auto-advance timer; a fourth keyed on `[gDone, approvalMode]` owns the
  full-auto re-loop. Each effect's cleanup (`clearTimeout`/`clearInterval`)
  is what gives "restart cancels any pending timer" for free — no manual
  ref-based `clearTimeout` bookkeeping needed outside the effects themselves
  (contrast with `terminal.tsx`'s single self-contained effect — a 4-effect
  split is the right call once a design's state machine has this many
  interacting phases/timers, not overengineering).
- The one exception needing a manual ref: the one-shot `raceStep` interval
  must stop itself once it hits its ceiling (12) without ever restarting —
  a plain `setInterval` effect on `[]` runs forever unless told otherwise, and
  there's no state transition that should tear down and recreate this effect
  (its deps never change after mount). Store the interval id in a `useRef`
  and clear it from a _second_, separate effect keyed on `[raceStep]` once
  the value reaches the ceiling. Splitting "create the interval" and "decide
  when to kill it" into two effects avoids the antipattern of clearing/
  recreating the interval every single tick (which a single combined effect
  keyed on `[raceStep]` would do).
- `getByText('spec')` / `getByText('1')` exact-string queries collide when
  the same literal also appears as an isolated span elsewhere in the same
  tree (e.g. the estimate slider's endpoint labels `<span>1</span>…<span>13</span>`
  collide with a threshold-stepper value that later reads `1`/`8` after
  clamping). Don't reach for `getByText` for a bare number/short token that
  recurs — grab the specific DOM neighbor instead
  (`decBtn.nextElementSibling?.textContent`), which is robust regardless of
  what number happens to also appear elsewhere.
- Deliberately mutated `storyPts <= thresh` to `storyPts < thresh` mid-session
  to confirm the two boundary-sensitive spec tests (lightweight-routing +
  AC4 re-sync) actually go red for that exact reason before restoring the
  fix — both failed as expected (`spec`/`plan` gates reappeared because the
  default 8-pts-vs-8-thresh case fell through to full ceremony), then passed
  clean again after the revert. Real red→green evidence for a boundary
  condition, not just "tests exist."
- `pnpm nx run @nightshift-ai/marketing:build` (Turbopack, Next 16, no
  `DATABASE_URL`/DB running in this session) again statically prerenders `/`
  successfully with the new section added — reconfirms the NA-32/NA-33
  finding that static composition sections with zero Payload calls don't
  need a live DB at build time, even as the page keeps growing.

**Patterns:**

- A derived-value function set (`buildTriageLanes`, `buildTriageMsg`,
  `buildCtrlGates`, `buildRaceLeft`, `buildRaceRight`, `buildApprovalModeHint`)
  as plain module-scope pure functions of `(state, route, routeName)`,
  called fresh every render inside the component body (never memoized,
  never stored in state) is the concrete implementation of an AC4-style
  "these N views can never desync" requirement — there is only one state
  object, and every view is a deterministic projection of it recomputed on
  every render pass.
- Task 10 ("visual parity", explicitly plan-tagged "(QA phase)") was
  deferred rather than attempted inline — the plan itself scopes it to a
  later QA phase (Playwright vs `docs/design/marketing-site-handoff/screenshots/`),
  and this session had no live dev server/DB. When a plan task is explicitly
  phase-tagged for a different agent/phase than the one you were dispatched
  as, don't force it into the current dispatch — flag the deferral in the
  return summary instead.

## 2026-07-12 — Story NA-33 — home how-it-works + trust sections (4 static sections + TeamPreview client state)

**Learnings:**

- The design handoff's tree-derivation logic (`nightshift Landing.dc.html`
  L1083-1182) references three overlapping-but-distinct agent data shapes:
  `agents` (L1361-1373, `name/owns/tone/standby`), `CONST_DEFS` (L665-676,
  `name/ini/x/y/owns/artifact` — used for a network-graph view out of this
  story's scope), and `ORG_LEVELS[].seqs` (L716, per-agent sequence label
  for the L5 fan-out only). A spec/plan that hands you one "exact type" for
  the roster (here `TeamAgent` = name/owns/tone/standby only) is
  deliberately narrower than the full design data — don't try to cram
  `ini`/`artifact`/`seqs` into the exported type to "complete" it; keep
  that derived/design-only data as a local `Record<string, ...>` lookup
  inside the one client component that needs it (`team-preview.tsx`), and
  extend the shared type with an _optional_ field only when the plan
  explicitly calls out data that must live on the shared shape across
  phases (here: `OrgPhase.seqs?: Record<string,string>` for the L5 case) —
  optional-field addition doesn't violate "exact types" since the required
  fields are still all present; TS excess-property checks only fire on
  fields _not_ declared on the interface at all.
- Tailwind v4 arbitrary-value animation classes
  (`motion-safe:animate-[ns-twinkle_var(--dur-twinkle)_ease-in-out_infinite]`)
  work fine referencing a `@keyframes` block already declared in
  `global.css` for an unrelated component (`ns-twinkle` was defined for
  `NightSky`'s starfield) — no new keyframes needed for a second consumer.
  Confirmed this repo already carries a _separate_, page-wide
  `@media (prefers-reduced-motion: reduce)` guard that zeroes all
  `animation-duration`s globally — the plan's explicit "gate behind
  `motion-safe`" instruction is therefore belt-and-suspenders on top of
  that guard, not the only protection; still worth doing literally since
  it's independently testable via `className` assertion (`[class*="motion-safe:animate"]`)
  without needing a `matchMedia` mock in the component test.
- React's inline-`style` prop serializes to the DOM's `style` attribute
  with a space after each colon and a trailing semicolon per declaration
  (`"opacity: 1; transition: opacity .2s;"`), **not** the no-space
  `key:value` form you'd write by hand in a `<style>` block. Any RTL test
  asserting `getAttribute('style')` content (the established pattern for
  custom-property-valued styles, per the NA-30 memory entry below) must
  match `'opacity: 1'`/`'opacity: 0.45'` with the space, or the assertion
  fails even though the real rendered value is correct — confirmed by
  running the test both ways and reading the actual serialized string.
- `getByText(label).closest('div')` is a reliable way to grab "the row
  container" for a hover-state test when the row is rendered as a flat
  `<div onMouseEnter=...>` containing several sibling `<span>`s (prefix,
  gate glyph, twinkle dot, label, note) and the label text itself sits in
  its own `<span>{label}</span>` with no nested markup — `getByText` finds
  that leaf span (single direct text-node child, matches the memory's
  earlier `getNodeText` caveat), and `.closest('div')` walks up to the row
  wrapper without needing `data-testid` anywhere in the component (this
  codebase has zero prior `data-testid` usage — kept that convention).
- `next build` (Turbopack, Next.js 16) with zero DB calls in the changed
  route tree remains a reliable free `tsc`-equivalent signal for a
  no-`typecheck`-target project (repeats the NA-32 finding) — caught
  nothing new here, but is worth running every story that touches
  `.tsx` even when `pnpm nx test`/`lint` are both green, since Jest's
  `ts-jest`/`swc` transform and ESLint's type-aware rules don't
  necessarily catch every type error a full `tsc` pass would.

**Patterns:**

- Deriving a box-drawing terminal tree (`├──`/`└──`/`│   ` continuation
  glyphs) from a small ordered list of "phase" objects, each owning 1-N
  "leaf" objects, with one phase (L5 here) needing extra nested fan-out:
  build the flat row array **once at module scope** (not inside the
  component, not in `useMemo`) from the static imported data — since the
  input is 100% static, a plain top-level `const TREE_ROWS = buildTreeRows()`
  is both simpler than a memoized hook and guarantees SSR/client markup
  matches exactly (no hydration mismatch risk from date/random-driven
  derivation, and no wasted per-render recomputation).
- Simple "hover row → highlight it, dim the rest, show its detail in a
  sticky side panel; leave the whole tree → reset" needs only one
  `useState<string | null>` for the active key plus a **pure function**
  `getSidePanel(active): SidePanel` that switches on whether `active` is
  `null`, the special human key, a name found in the roster map, or a
  phase `num` found in the levels array, returning one of a handful of
  literal shapes — keeps all the "what do I show" branching out of JSX
  entirely and trivially testable in isolation if a story needed it.

> **Design source of truth (2026-07-12):** for any marketing-site work, follow
> `docs/features/2026-07-12-nightshift-marketing-site-design-handoff.md` (→
> `docs/design/marketing-site-handoff/`). Pre-NA-29 design-direction entries were
> removed from this file (see git history); the framework/tooling learnings below
> (GSAP, Payload, Jest, worktrees) remain valid.

## 2026-07-12 — Story NA-32 — review-fix: full-bleed bands + classic scrollbar gutter

**Learnings:**

- The `relative left-1/2 right-1/2 -mx-[50vw] w-screen` full-bleed-band
  trick (used by `ProofBar`/`PhraseMarquee`/`ProblemSection` to break out
  of the shared `max-w-[var(--container-max)]` `<main>`) is built on
  `100vw`, which **includes the vertical scrollbar gutter** on classic
  (non-overlay) scrollbar platforms — Windows/Linux Chrome, not macOS's
  overlay scrollbars. Because neither `body`/`html` nor `<main>` set
  `overflow-x` anywhere in this codebase, that ~15-17px overshoot became a
  real page-wide horizontal scrollbar, invisible in a macOS-rendered
  screenshot QA pass (the usual visual-parity gate) but a genuine
  regression on the more common desktop-Chrome scrollbar style. Any
  future `-mx-[50vw] w-screen` full-bleed band inherits this same risk —
  it's a property of the pattern, not this specific section.
- Fix is a single `overflow-x: clip` on `body` (not `overflow-x: hidden`)
  — `clip` suppresses the resulting scroll without disabling
  `position: sticky` on any descendant (a real risk with `hidden`, which
  also clips scroll containers, whereas `clip` only clips paint/scroll on
  the box it's set on and doesn't establish a new scroll container the
  way `overflow: hidden`/`auto`/`scroll` do). One-line, no `@theme`/token
  changes needed, and doesn't require touching any of the three full-bleed
  components themselves.

## 2026-07-12 — Story NA-32 — home hero, proof bar, problem section (3 new ui primitives)

**Learnings:**

- **jsdom (this repo's `testEnvironment: 'jsdom'`, jsdom@26) implements
  neither `window.matchMedia`, `window.IntersectionObserver`, nor
  `window.requestAnimationFrame` by default** — confirmed by instantiating
  `JSDOM` directly and checking `typeof`. Any client component that calls
  these unconditionally (the established pattern in this codebase —
  `cursor-glow.tsx` calls `window.matchMedia` with no defensive guard,
  relying on every consuming test to mock it) will throw in a test that
  doesn't mock them first. This matters beyond the component's own spec
  file: a **page-level test that renders the component indirectly** (e.g.
  `page.spec.tsx` rendering `HomePage` → `Hero` → `Terminal`) inherits the
  same requirement and needs the same `window.matchMedia = jest.fn()...`
  mock added, or it breaks with no obvious connection to the actual change
  (the page test file itself never touches `Terminal`). Grep for which
  primitives a page composes before assuming an existing page spec still
  passes unmodified.
- Because `IntersectionObserver` is unsupported in jsdom by default, a
  `CountUp`-style "animate on first viewport entry, unsupported → render
  final value" component's **"unsupported" degrade path fires automatically
  in every test that doesn't explicitly install a fake
  `window.IntersectionObserver`** — useful for one branch (asserting the
  final value renders immediately) but means the "renders `0` initially"
  branch needs its own test that installs a no-op fake class (`observe`/
  `disconnect` as `jest.fn()`, never invoking the stored callback) so the
  component takes the `rAF`-driven path instead and never reaches 0→final
  in the test's synchronous window.
- `@testing-library`'s `getByText` uses `getNodeText(node)` under the hood,
  which is **not** `node.textContent` — it only concatenates a node's
  _direct_ text-node children, deliberately excluding text inside child
  elements. A composed line like
  `<span><CountUp>11</CountUp> specialized agents</span>` therefore has
  **no single node** whose own text equals `"11 specialized agents"` — the
  number lives in `CountUp`'s own `<span>`, the label is a separate text
  node on the parent. `getByText(/11 specialized agents/i)` fails with
  "text is broken up by multiple elements" even though the rendered page
  visually reads that way. Fix for page-composition-level assertions:
  check `container.textContent` (which _does_ recurse) instead of
  `getByText` when the text you're asserting spans a primitive boundary.
- Reduced-motion self-guards only need to check `matchMedia` **once, in an
  effect, before the first line of listener-wiring code** — they do not
  need a defensive `typeof window.matchMedia === 'function'` check in this
  codebase's convention (every consumer test mocks it), but effects that
  additionally call `requestAnimationFrame` (ambient idle-drift, not
  covered by the `matchMedia` check because it only gates _whether_ the
  effect's `if` bails, not whether `rAF` itself exists) DO need a
  `typeof window.requestAnimationFrame !== 'function'` guard — otherwise a
  non-reduced-motion test (which is the common case, `matchMedia` mocked
  to `matches: false`) throws immediately on mount in jsdom, since `rAF` is
  unconditionally absent there regardless of the reduced-motion mock.
- `next build` (Turbopack, Next.js 16) on the plain `/` route with zero
  Payload/DB calls in the new page tree statically prerenders successfully
  with **no `DATABASE_URL`/DB at all** — confirms static composition
  sections (no `findGlobal`/`find` calls) don't inherit the "needs a
  migrated Postgres schema at build time" constraint documented in the
  NA-16 entry below (that constraint is specific to pages that actually
  call Payload's Local API). Good fast way to get real `tsc`-equivalent
  type-checking signal for a story with no repo `typecheck` target — `next
build` runs the full TypeScript pass before prerendering.
- No `gsap` or `motion`/`framer-motion` package is installed anywhere in
  this workspace (`grep` across every `package.json` came back empty),
  despite both being listed as required override skills for this story.
  Adding either would touch the lockfile, which is out of scope without
  explicit instruction. The existing codebase's convention for every
  interactive/ambient effect (`cursor-glow.tsx`, `night-sky.tsx`,
  `nav-bar.tsx`) is vanilla React + direct DOM style mutation +
  `matchMedia`/`requestAnimationFrame`, with **no** animation library
  dependency — followed that same convention for `Terminal`'s magnetic
  tilt + idle drift (manual `perspective()/rotateX/rotateY` transform
  strings via `el.style.transform`, no GSAP `quickTo`/matchMedia helper)
  rather than introducing a new dependency the skill's own docs would
  otherwise suggest.

**Patterns:**

- Faux-terminal "reveal N of M scripted lines on a cadence, then loop"
  primitive: a single piece of state (`visibleCount`, starting at `1` for
  a deterministic SSR/hydration frame) plus one `setInterval` that does
  `setVisibleCount(c => c >= lines.length ? 1 : c + 1)` is sufficient for
  both the reveal and the loop-restart — no separate "loop" branch needed.
  Reduced motion swaps this for one synchronous `setVisibleCount(lines.length)`
  and returns before the interval is ever created (assert via
  `jest.spyOn(window, 'setInterval')` + `expect(...).not.toHaveBeenCalled()`
  in the reduced-motion test).
- Full-bleed band inside a `max-w-[var(--container-max)]` centered `<main>`:
  `relative left-1/2 right-1/2 -mx-[50vw] w-screen` on the section itself
  (breaks out to true viewport width regardless of `<main>`'s max-width),
  then a plain `mx-auto` inner wrapper with its own `max-width` + padding
  re-centers the content — no portal, no restructuring of the shared
  layout shell required. Reused for both the Proof bar (needs a tinted
  background band) and the Problem section (needs the oversized ghost
  `80%` glyph to be able to clip at true viewport width, even though the
  section itself has no background tint).

## 2026-07-12 — Story NA-31 — CMS FAQ collection + whySdlc global, content-only (no rendering)

**Learnings:**

- **`payload run <script>` exits before an unawaited async body finishes —
  use top-level `await`, not a fire-and-forget IIFE.** The CLI (`payload/dist/bin/index.js`,
  `run` branch) does `await import(scriptPath)` then immediately calls
  `process.exit(0)`. Dynamic `import()` only waits for a module's _top-level_
  `await` chain; a `(async () => { ... })().catch(...)` body at the top of the
  script is fire-and-forget from the module's perspective, so `import()`
  resolves as soon as that promise is _scheduled_, not settled — the CLI then
  kills the process before even the first `await getPayload(...)` inside it
  resolves (confirmed with a `process.exit` wrapper + stack trace: the trace
  pointed at `bin()` in payload's CLI, not at anything in the script).
  Symptom: the script silently produces zero rows/updates and exits 0 with no
  error, no matter what logging you add inside the unawaited function — because
  none of that code ever gets a turn on the event loop. Fix: write the seed
  body as bare top-level statements (`const payload = await getPayload(...)`
  followed by `await` calls, no wrapping function) so the module's own
  evaluation — which `import()` genuinely waits on — doesn't finish until the
  DB work is done.
- `getPayload({ config })` triggers Payload's Postgres **dev schema push**
  (`pushDevSchema` in `@payloadcms/drizzle`) whenever
  `NODE_ENV !== 'production'` and `PAYLOAD_MIGRATING !== 'true'`, _even after_
  `payload migrate` already applied a matching schema — it diffs and applies
  again every `getPayload()` call in dev mode. If Drizzle's diff produces
  `warnings` (rare once schema is settled, but possible on first push) it
  calls the `prompts()` library, which in a non-interactive shell (no TTY)
  fires `onCancel` immediately and calls `process.exit(0)` — another silent,
  zero-output early exit, this time from inside `pushDevSchema.js` itself, not
  the CLI wrapper. Running the script with `NODE_ENV=production` skips this
  branch entirely (relies purely on applied migrations, no push, no prompts) —
  useful for scripted/CI seed runs even though the app's real prod deploy
  target is Vercel, not this local flow.
- No live Postgres was reachable in this sandbox — `docker info`/`docker ps`
  hung/timed out even with `dangerouslyDisableSandbox: true` and even though
  `ps` showed Docker Desktop's backend processes running (VM likely wedged,
  not a permissions issue). Homebrew's `postgresql@14` binaries
  (`/opt/homebrew/bin/{initdb,pg_ctl,psql}`) were available as a fallback:
  `initdb -D <scratch>/pgdata -U postgresql --auth=trust`, then
  `pg_ctl ... -o "-p 5433 -h 127.0.0.1 -c unix_socket_directories=''" start`
  — the `unix_socket_directories=''` flag is required because Postgres's
  Unix-socket path has a ~103-byte OS limit and this project's scratchpad
  path is longer than that; disabling the socket and forcing TCP
  (`-h 127.0.0.1`) sidesteps it entirely. Pointed `apps/marketing/.env`'s
  `DATABASE_URL` at the scratch instance only for the verification session,
  restored the committed placeholder value afterward (`.env` is gitignored,
  so this never touched a tracked file) — this is how `payload generate:types`,
  `migrate:create`, `migrate`, and the seed idempotency check (AC ti-3) all
  got real red→green evidence in an environment with no reachable
  docker-compose/Neon DB.
- Mixing one array element typed as the broad `Field` union (e.g. a
  `const groupField: Field = {...}` extracted per the payload skill's own
  "annotate extracted constants" guidance) with the other elements left as
  inline object literals in the same `fields: [...]` array **degrades
  TypeScript's contextual typing for the other elements' `validate`
  callbacks** — `(value, { siblingData }) => ...` on a sibling `type:
'number'` field literal came back "Parameter 'value' implicitly has an 'any'
  type" at `next build`'s typecheck step, even though that field itself was a
  plain inline literal. Root cause isn't the skill's guidance being wrong per
  se — it's that a _mixed_ array (one broadly-typed element + literals) seems
  to break per-element discriminated-union narrowing for the literals too.
  Fix: don't extract `validate`-bearing fields as loosely-typed constants at
  all; either keep every field a fully inline literal, or (more robust, and
  what actually fixed it here) type the `validate` function itself against
  Payload's specific exported validation type (`NumberFieldSingleValidation`,
  `TextFieldSingleValidation`, etc., all exported from `'payload'` — see
  `payload/dist/fields/validations.d.ts`) as a factory: `const
requiredWhenFlagged = (flagField): NumberFieldSingleValidation => (value, {
siblingData }) => {...}`. That sidesteps contextual-typing entirely and is
  reusable across the two symmetric order fields.
- `payload generate:types`, `migrate:create`, and `migrate` all worked
  correctly against a fresh/empty DB with **zero prior migrations** in this
  app — a prior story (NA-22) had committed globals + a migration, but a
  later reset commit (`feat(marketing)!: reset app to empty Payload +
Next.js shell`, ancestor of current `develop`) deleted them, so NA-31's
  generated migration is again a from-scratch baseline (creates `faq`,
  `media`, `users`, `users_sessions`, `payload_migrations`, etc. — not just
  the two new tables). Expected, not a mistake — check `git log --oneline -- <path>`
  history before assuming a resurfaced file/table pattern is stale
  duplication.

**Patterns:**

- Verifying a Payload seed's idempotency contract (AC-style "second run
  never duplicates") end-to-end without a project-provided test harness:
  run the seed once (`pnpm exec payload run src/seed/seed.ts`, or via the
  npm `seed` script), assert row/child count via a direct `psql` query, run
  it again, assert the same count plus that every doc's `updatedAt`-affecting
  fields changed to "updated" not "created" in the log output. For a Payload
  **array** field on a global (e.g. `whySdlc.arguments`), Payload stores rows
  in a `<slug>_<arrayFieldName>` child table (`why_sdlc_arguments`) — count
  and order-check that table directly (`array_agg(col ORDER BY _order)`)
  rather than trying to introspect the parent `jsonb` (arrays aren't stored
  as jsonb on Postgres, only `richText`/`group` fields are).
- Building one-paragraph Lexical `richText` seed values by hand without a
  helper library: a single `{ root: { type:'root', children:[{ type:
'paragraph', children: [...textNodes], direction:'ltr', format:'', indent:0,
version:1 }], direction:'ltr', format:'', indent:0, version:1 } }` shape is
  sufficient for plain-prose CMS copy; inline `code` marks (e.g. `/auto`)
  are just another text node in the same paragraph with `format: 16` (Lexical's
  `IS_CODE` bit) instead of `format: 0` — no need for the full
  `@payloadcms/richtext-lexical` node-builder API for straightforward seed data.

## 2026-07-10 — Story NA-16 — interactive 3D hero landing page

**Learnings:**

- Payload global content (`payload.findGlobal`) returns each field's
  `defaultValue` even before any document row exists in the DB — this is
  the correct way to satisfy "renders without manual CMS entry" without a
  seed script.
- `pnpm exec payload generate:types` (run from `apps/marketing`) needs a
  _reachable_ Postgres (`DATABASE_URL`) to instantiate Payload, but does
  **not** need the actual tables/schema to exist — it only reads the config.
  Use `pnpm nx run @nightshift-ai/marketing:local-start` /
  `:local-stop` (docker compose) to get a throwaway DB for this.
- The docker-compose project/container names in `apps/marketing/docker-compose.yml`
  are fixed (`nightshift_postgres` etc, not worktree/branch-scoped) — running
  `local-start` from one worktree will recreate/collide with containers from
  any other worktree using the same compose file. Stop it again when done
  (`local-stop`) so you don't strand a container.
- Git worktree gotcha: `cd` inside a Bash call to the _shared_ checkout path
  (`nightshift/...` without the `.claude/worktrees/<agent-id>/` prefix) will
  silently operate on the wrong git checkout — `git checkout <branch>` there
  can steal a branch out from under another worktree ("branch already used
  by worktree" on retry). Read/Write/Edit tools correctly refuse this, but
  Bash does not. Always prefix paths with the worktree root for every tool.
- A fresh git worktree has no `node_modules` — `pnpm install --frozen-lockfile`
  from the worktree root reuses the shared pnpm store and is fast (~a few
  seconds), no network fetch needed if the store is already warm.

**Pitfalls:**

- Adding a Payload `findGlobal`/`find` call directly in a Next.js App Router
  page makes that route attempt static prerendering at `next build` time by
  default — which then requires a **migrated** Postgres schema to exist
  (not just a reachable DB.) A brand-new global with no migration yet fails
  build with `relation "<slug>" does not exist`. Fix: add
  `export const dynamic = 'force-dynamic';` to the page so Payload is only
  queried at request time — this is also the _more correct_ choice for
  CMS content that must reflect admin edits without a redeploy. Don't try
  to fight the DB-at-build-time requirement (e.g. by faking data) if you
  can instead just defer rendering — check first whether the page even
  needs to be statically prerendered.
- Testing an async Server Component with Jest + `@testing-library/react`
  does **not** work by nesting it as JSX (`<Page />`) inside another
  render — React's client renderer errors because the component returns a
  Promise. The working pattern: call the async component function yourself
  and hand the resolved element tree to `render()`, e.g.
  `render(await Page())`. Keep the async work at a single top-level
  boundary (the page itself) rather than nesting a second async component
  inside it, or this pattern doesn't compose.
- `@testing-library/jest-dom` (`toBeInTheDocument`, `toHaveAttribute`, etc.)
  is **not** installed in this workspace — the existing test setup only
  gives you the base Jest matchers. Use `.toBeTruthy()` /
  `.getAttribute(...)` comparisons instead, don't add the dependency for a
  single story without an explicit instruction (touches the lockfile).
- GSAP type predicate gotcha: narrowing an array of `HTMLXRef.current`
  values (different concrete HTML element types) to a single named DOM type
  (e.g. `el is HTMLElement`) fails `next build`'s TypeScript pass
  ("type predicate's type must be assignable to its parameter's type") when
  the union includes a type not assignable _from_ that name (e.g.
  `HTMLAnchorElement` isn't narrowed _to_ by declaring `HTMLElement`, even
  though it's a supertype). Use `el is NonNullable<typeof el>` instead of
  naming a concrete type.
- GSAP's transform aliases are `rotationX`/`rotationY` (not `rotateX`/
  `rotateY`) — passing the CSS-style names to `gsap.quickTo`/`gsap.to`
  silently does nothing.

**Patterns:**

- `gsap.matchMedia({ reduceMotion: '(prefers-reduced-motion: reduce)' }, ...)`
  is the single place to branch: skip the entrance timeline, skip the
  pointermove listener, skip the ScrollTrigger creation, and `gsap.set(...)`
  straight to the final visible state when `reduceMotion` is true. Testable
  by mocking `gsap.matchMedia`'s `add(query, handler)` to capture the
  handler and invoking it directly with both `{ reduceMotion: true }` and
  `{ reduceMotion: false }`, then asserting which GSAP calls fired.
  **CORRECTED 2026-07-10 (NA-16 code review, see below): this pattern is a
  CRITICAL bug** — see the entry below for why and the fix.

## 2026-07-12 — Story NA-30 — site-wide night-sky chrome + Tailwind v4 token layer

**Learnings:**

- Standing up Tailwind v4 CSS-first from zero in this repo: `pnpm add -D
tailwindcss @tailwindcss/postcss postcss --filter @nightshift-ai/marketing`
  - a two-line `postcss.config.mjs` registering `@tailwindcss/postcss` is
    the entire pipeline — no `tailwind.config.js`, no `content` array (that's
    what `@source` inside the CSS is for).
- Adding `@nightshift-ai/ui` as a real `workspace:^` dependency of
  `apps/marketing` (previously it was an empty unused shell) makes Nx's
  TS project-references sync go stale — `pnpm nx <any-target>` then fails
  fast with "The workspace is out of sync" before running anything. Fix:
  `pnpm nx sync` once (it silently patches `apps/marketing/tsconfig.json`
  `references`); a second `nx sync` confirms "already up to date". Do this
  right after the `pnpm add` for the workspace package, before any other
  verification command.
- `packages/ui` has no `node_modules` of its own and never needs `react`/
  `next`/`@testing-library/*` added to its own `package.json` — it's a real
  (non-symlinked) subdirectory of the repo root, so Node's directory-walk
  module resolution reaches the root `node_modules` (where `react`/`next`
  are hoisted as root `package.json` deps) on its own. Confirmed via
  `tsc --build` + `next build` + `jest` all resolving `next/link`,
  `next/navigation`, `react` from `packages/ui/src/**` with zero added
  deps there.
- `packages/ui`'s `tsconfig.lib.json`/`tsconfig.spec.json` only had
  `"lib": ["es2022"]` (inherited from `tsconfig.base.json`, no DOM) and
  `packages/ui/jest.config.cts` had no `testEnvironment` (defaults to
  `node`) — because the package was an "empty shell" before this story.
  Any `'use client'` component using `window`/`PointerEvent`/DOM methods
  needs `"lib": ["es2022", "dom", "dom.iterable"]` added to **both**
  `tsconfig.lib.json` and `tsconfig.spec.json` (typecheck runs each
  separately — fixing only one still fails the other), plus
  `testEnvironment: 'jsdom'` in `jest.config.cts` for RTL tests to run at
  all.
- next/font self-hosting + Tailwind v4 `@theme` compose cleanly by giving
  the font loader a **private** CSS variable name (`variable:
'--font-inter'`, not `'--font-sans'` directly), applying that class on
  `<html>`, and then writing `--font-sans: var(--font-inter), <fallback
stack>;` inside `@theme` yourself. Letting next/font own `--font-sans`
  directly is fragile (cascade/specificity race between the font loader's
  injected class and `@theme`'s `:root` rule); owning the final variable
  in your own stylesheet is deterministic regardless of injection order.
  Network access to Google Fonts was available at build time in this
  sandbox (`next/font/google` fetches once at build and self-hosts the
  result — no runtime Google Fonts request survives to the client either
  way).
- This design system's token file reuses the `--text-*` prefix for two
  unrelated concerns: the Tailwind-recognized font-size scale
  (`--text-2xs…6xl`, correctly drives `text-sm`/`text-lg`/etc utilities)
  _and_ semantic text-color aliases (`--text-strong`, `--text-body`,
  `--text-muted`, ...). Tailwind v4 only emits a utility for a theme key
  when that literal class name is actually referenced in scanned source —
  it does **not** eagerly generate one for every theme entry — so this
  latent collision (a hypothetical `.text-strong{font-size:var(--moon-100)}`)
  never materializes in the build as long as you never write
  `className="text-strong"` and always reach color aliases via
  `text-[var(--text-strong)]` bracket syntax instead. Confirmed by
  grepping the built CSS chunk: no `.text-strong` rule exists even though
  the token is declared in `@theme`.
- jsdom's `CSSStyleDeclaration` (via the `cssstyle` package) validates
  known numeric CSS properties strictly and silently rejects a `var(...)`
  value for `opacity` specifically — `element.style.opacity` reads back as
  the string `"NaN"` in tests even though the real browser (and the actual
  rendered `style` attribute) is fine with `opacity: var(--token)`. Don't
  assert `.style.<prop>` for custom-property-valued numeric CSS properties
  in RTL/jsdom tests; either assert the raw `getAttribute('style')` string,
  or (preferred, and more idiomatic Tailwind besides) express the value as
  an arbitrary-value utility class (`opacity-[var(--token)]`) and assert
  on `className` instead — sidesteps jsdom's CSSOM validation entirely.

**Patterns:**

- CSS-only rest/hover/press/focus-visible state components (the neon
  `CtaButton`, the hover-lift `Card`) can stay **server components** with
  zero client JS by expressing every state as a Tailwind pseudo-class
  variant referencing the design token directly:
  `bg-[var(--btn-neon-bg)] hover:bg-[var(--btn-neon-hover-bg)]
active:bg-[var(--btn-neon-press-bg)] focus-visible:shadow-[var(--glow-focus)]`.
  Multi-layer `box-shadow` values (comma-separated, itself containing
  `var()` calls) work fine as a single Tailwind arbitrary value, e.g.
  `hover:shadow-[var(--glow-neon-hover),var(--shadow-pop)]` — commas
  don't need escaping in Tailwind's bracket syntax, only bare spaces do
  (use `_` there). This avoids needing `'use client'` + `useState` hover
  tracking that the design system's own throwaway `.jsx` prototypes use.
- One global `@media (prefers-reduced-motion: reduce)` guard
  (`*,*::before,*::after { animation-duration:.01ms!important;
animation-iteration-count:1!important; transition-duration:.01ms!important; }`)
  in the base stylesheet covers every CSS-only animated/transitioning
  component for free (`NightSky`'s twinkle/drift keyframes, `CtaButton`'s
  hover transition, `Card`'s hover transition) — no per-component reduced-
  motion branching needed for those. JS-driven state (`CursorGlow`'s
  pointer tracking, `NavBar`'s scroll-detach threshold) still needs an
  explicit `matchMedia('(prefers-reduced-motion: reduce)')` check in the
  component itself, since the CSS guard can't stop a `useEffect` from
  attaching a listener or setting state in the first place.
- Deterministic "starfield" dot layers for a `'use client'` background
  component: hardcode the dot coordinate arrays as module-level constants
  instead of `Math.random()` at render time. A client component still
  renders once on the server for SSR — random values there would mismatch
  the client's hydration pass and React would warn/reconcile incorrectly.
  Layer the CSS as a single `background-image` of `radial-gradient(<s>px
<s>px at <x>% <y>%, <color> 0, <color> 42%, transparent 78%)` calls
  joined by commas, tiled via `background-repeat: repeat` +
  `background-size: 520px 520px`.

## 2026-07-10 — Story NA-16 — code-review fix pass (matchMedia bug, DB fallback, tests)

**Learnings:**

- GSAP's real `MatchMedia.add(conditions, handler)` (gsap-core.js) only
  invokes `handler` when **at least one** named condition's media query
  actually matches (`active = 1` per matching query; `active && func(...)`).
  Registering only `{ reduceMotion: '(prefers-reduced-motion: reduce)' }`
  means a default user (no explicit motion preference either way) matches
  _nothing_ → the handler never runs → no entrance animation, ever, for the
  common case. Always pair `reduceMotion` with its complement
  `allowMotion: '(prefers-reduced-motion: no-preference)'` so the handler
  is guaranteed to fire. Read `node_modules/.pnpm/gsap@*/node_modules/gsap/gsap-core.js`
  directly (`grep -n matchMedia`) to verify this contract instead of trusting
  intuition about what "should" happen — this is exactly the bug the
  previous memory entry (immediately above) shipped and mis-documented as a
  correct pattern.
- A jest mock that just captures `mm.add`'s handler and invokes it manually
  with a hand-picked `{ conditions }` object (as the original hero-client
  spec did) tests the mock's own fabricated behavior, not GSAP's real
  "any-condition-matches" contract — it would pass even with the
  single-condition bug in place. Fix: reimplement the mocked `add()` to
  compute `conditions` from a stubbed `window.matchMedia(query).matches`
  per query and only invoke `handler` if `Object.values(conditions).some(Boolean)`
  — mirrors gsap-core's real semantics well enough to make the regression
  test fail against the buggy source.
- `@payload-config` is a tsconfig path alias (`./src/payload.config.ts`),
  not a real installed package — `next/jest`'s automatic
  tsconfig-paths-to-moduleNameMapper wiring does **not** cover it (unclear
  why; possibly because it's not prefixed like a typical `@/*` wildcard).
  `jest.mock('@payload-config', factory)` without options throws "Cannot
  find module" before the mock can even apply. Pass `{ virtual: true }` as
  the third arg to mock it without requiring real resolution.
- Don't co-locate small "fallback/default content" data next to a Payload
  `GlobalConfig`/`CollectionConfig` object if a plain server function needs
  to import just the data — the config file's other imports (e.g. an
  `afterChange` hook using `next/cache`'s `revalidatePath`) drag in
  Next.js-internal code that breaks (`ReferenceError: TextEncoder is not
defined`) when required from a jsdom test environment. Put the shared
  literal in its own dependency-free module (e.g. `lib/hero-defaults.ts`)
  and import it from both the Payload config and the plain data-access
  function.

**Pitfalls:**

- `jest.mock('module', () => ({ fn: jest.fn().mockResolvedValue(outerConst) }))`
  throws `ReferenceError: Cannot access 'outerConst' before initialization`
  when `outerConst` is declared with `const`/`let` anywhere in the same
  file — `jest.mock()` calls (and the ESM→CJS `require()`s they precede)
  get hoisted above regular `const` declarations by babel-plugin-jest-hoist,
  so the const's TDZ hasn't closed yet when the factory runs. Variables
  prefixed with `mock` (case-insensitive, e.g. `mockFindGlobal`,
  `mockGetPayload`) are a documented exception — babel-plugin-jest-hoist
  hoists those declarations too, so referencing them from inside a
  `jest.mock` factory works. For anything not `mock`-prefixed, either
  duplicate the literal inline in the factory or read it back via
  `jest.requireMock(...)` inside the test body instead.
- Two concurrent dispatches for the same story branch can leave an orphaned
  `git worktree` holding that branch checked out (e.g. a crashed/aborted
  prior session). The Edit/Write tools refuse to touch files outside your
  own assigned worktree even if you `cd` there via Bash, and `git checkout
<branch>` fails with "branch already used by worktree" if another
  worktree holds it. Fix: `git worktree remove <other-worktree-path>` (only
  safe once it's clean — `git -C <path> status --porcelain` first, and
  discard trivial auto-generated diffs like `next-env.d.ts` if that's all
  that's dirty), then `git checkout <branch>` in your own worktree.

**Patterns:**

- Server-only "read CMS content, fall back to static defaults on any
  failure" shape: `try { return await payload.findGlobal(...); } catch (e) {
console.error('[context]', e); return sameDefaultsUsedAsFieldDefaultValue; }`.
  Narrow the return type to `Pick<GeneratedType, 'fieldsActuallyConsumed'>`
  rather than the full generated type — avoids having to fabricate a fake
  `id`/`createdAt` for the fallback case.

## 2026-07-10 — Story NA-16 — Copilot review-fix pass (open-redirect validator, GSAP paint flash)

**Learnings:**

- **Correction to the "orphaned worktree" pitfall above**: the branch can
  also be stuck checked out in the repo's **primary** (non-worktree)
  checkout, not just a linked `git worktree`. `git worktree remove` only
  works on linked worktrees — the primary one can't be removed. Fix there
  is `git -C <primary-path> checkout <other-branch>` (e.g. `main`) after
  discarding its trivial auto-generated diffs, which frees the branch for
  your own worktree's `git checkout <branch>`. Symptom to watch for:
  `git worktree list` shows the plugin's own repo root (no
  `.claude/worktrees/...` suffix) holding the target branch.
- `next build` (plain, no DB) regenerates `apps/marketing/next-env.d.ts`
  with a formatting-only diff (single vs double quotes in the import path)
  every run — expected noise, not a real change; discard before staging
  (`git checkout -- apps/marketing/next-env.d.ts`) rather than committing it.
- Payload global `validate` functions that reject `//scheme-relative` URLs
  need the regex `/^\/(?!\/)/`, not `value.startsWith('/')` — the latter
  also matches `//evil.example`, which browsers treat as an absolute
  navigation to `evil.example` (protocol-relative URL), defeating the
  "relative in-app path only" intent. Trim the input first so
  whitespace-only values fall through to the "required" branch instead of
  reaching the format check and returning the wrong error message.
- Importing a Payload `GlobalConfig` module (e.g. `Hero.ts`) directly in a
  jsdom Jest test to unit-test an exported validator function still pulls
  in the config's other imports transitively — here `revalidateHero` →
  `next/cache`, which throws `ReferenceError: TextEncoder is not defined`
  at import time in jsdom. `jest.mock('next/cache', () => ({
revalidatePath: jest.fn(), revalidateTag: jest.fn() }))` at the top of the
  spec file is enough; no need to relocate the validator to its own module
  just to test it.

**Pitfalls:**

- GSAP entrance tweens set up in a plain `useEffect` run after first paint,
  so the browser can flash the tweens' end state (from CSS/inline styles)
  before GSAP applies the `.from(...)` start state — visible as a brief
  "pop" on load, most noticeable on slow devices. `useLayoutEffect` isn't
  safe to call unconditionally in an SSR'd Next.js component (React warns
  "useLayoutEffect does nothing on the server"); use the standard
  isomorphic swap — `const useIsomorphicLayoutEffect = typeof window !==
'undefined' ? useLayoutEffect : useEffect;` — module-scoped once, reused
  by the component. jsdom runs layout effects synchronously, so existing
  RTL tests for the effect's side effects (matchMedia registration, GSAP
  calls) pass unchanged after the swap — no test updates needed for a
  behavior-preserving hook swap.

**Patterns:**

- TDD-verifying a validator fix in a diff-review-fix pass without a
  pre-existing spec file: write the new spec first, confirm it's GREEN
  against the fixed source (expected, since the fix is already applied),
  then temporarily swap the source back to the pre-fix version in place
  (e.g. via a scripted string replace) and rerun to see the exact new
  assertions go RED for the exact reason described in the review finding,
  then restore the fix. Gives real red→green evidence even when the fix
  was written before the test in the session's actual edit order.
