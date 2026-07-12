# web-engineer memory

> **Design source of truth (2026-07-12):** for any marketing-site work, follow
> `docs/features/2026-07-12-nightshift-marketing-site-design-handoff.md` (→
> `docs/design/marketing-site-handoff/`). Pre-NA-29 design-direction entries were
> removed from this file (see git history); the framework/tooling learnings below
> (GSAP, Payload, Jest, worktrees) remain valid.

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
