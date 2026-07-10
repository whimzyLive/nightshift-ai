# web-engineer memory

## 2026-07-10 — Story NA-16 — interactive 3D hero landing page

**Learnings:**

- `apps/marketing` is still the unmodified Nx/Next.js starter scaffold (NX
  logo, generic feature cards, no nightshift branding) — a separate GTM
  effort (`feat/gtm-site-refine-sections`, per prior memory/observations) is
  doing the full site rebuild. Stories scoped to a single section (like
  NA-16's hero) should touch only that section and leave the rest of the
  starter page alone rather than trying to "fix" the mismatch.
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

- Hero-local brand tokens: rather than importing the nightshift-design
  skill's `styles.css` (meant for static mock/prototype output, not a
  production app bundle) or editing the site-wide `global.css` for a
  single-section story, declare the exact hex values as CSS custom
  properties scoped to the component's own root class in its CSS module,
  with a comment noting they mirror `.claude/skills/nightshift-design/tokens/*.css`.
  Keeps brand-on-the-hero without leaking a site-wide theme change that's
  out of scope.
- Layered CSS 3D parallax without a 3D library: `perspective` on a static
  wrapper, `transform-style: preserve-3d` on an inner "scene" div that GSAP
  rotates (`rotationX`/`rotationY` via `gsap.quickTo`, driven by
  `pointermove`), and each visual layer inside it at a different
  `translateZ`. Avoids the three.js/`@react-three/fiber` bundle cost for a
  hero-only decorative effect — reasonable when the story explicitly allows
  choosing the lighter implementation.
- `gsap.matchMedia({ reduceMotion: '(prefers-reduced-motion: reduce)' }, ...)`
  is the single place to branch: skip the entrance timeline, skip the
  pointermove listener, skip the ScrollTrigger creation, and `gsap.set(...)`
  straight to the final visible state when `reduceMotion` is true. Testable
  by mocking `gsap.matchMedia`'s `add(query, handler)` to capture the
  handler and invoking it directly with both `{ reduceMotion: true }` and
  `{ reduceMotion: false }`, then asserting which GSAP calls fired.
  **CORRECTED 2026-07-10 (NA-16 code review, see below): this pattern is a
  CRITICAL bug** — see the entry below for why and the fix.

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

## 2026-07-10 — Story NA-21 — nightshift brand sections below the hero (how-it-works, team, install)

**Learnings:**

- This worktree's own branch can't literally `git checkout feat/<KEY>` if
  another worktree already has that exact branch checked out — the
  orchestrator pre-creates the impl branch and a worktree-local branch at
  the same commit for each dispatched agent. Verify with
  `git log --oneline -3 <worktree-branch>` vs `git log --oneline -3
feat/<KEY>` — if they match, you're at the right starting point and
  should just commit here; don't force-checkout the shared branch name.
- The nightshift-design skill's static-mock reference JSX
  (`ui_kits/marketing/sections.jsx`) is copy-paste gold for **content and
  data shape** (the exact IDEAS/TEAM/PIPELINE_LINES arrays, copy voice) even
  though its components aren't directly importable into a real Next.js app
  (they're namespaced globals meant for `templates/page-starter.html`).
  Reimplement the JSX by hand in the app, but lift the data verbatim.
  `references/components.md` + `references/patterns.md` give the exact
  hover/glow/hairline CSS recipes when hand-building instead of using the
  skill's own components.
- Extending the hero's per-component "mirror the tokens as local CSS custom
  properties" pattern (NA-16) to a _group_ of sibling components: define the
  `--ns-*` variables once on a shared wrapper `<div className={tokens}>` in
  the page, not per-component. CSS custom properties inherit through the
  DOM regardless of CSS-module class-name hashing, so every section's own
  `.module.css` can reference `var(--ns-accent)` etc. without each file
  redeclaring the full token set — avoids the NA-16 hero's per-component
  duplication once there are 5+ sibling components sharing one brand.
- A story's stated motion budget ("transform/opacity only, 120–360ms, one
  ease") applies to the _reveal/hover_ tweens, not literally everything
  with a duration — a scroll-triggered count-up (AC5-style) tweens a JS
  number driving `textContent`, not a CSS transform/opacity property, and
  needs longer (~1.2s) to actually read as "counting" rather than jumping.
  Keep the same named ease (e.g. `power3.out`) across every tween anyway
  ("one ease") even where duration reasonably exceeds the reveal budget,
  and comment the deliberate exception so a reviewer doesn't file it as a
  brand-adherence miss.
- `apps/marketing-e2e`'s shared `tsconfig.base.json` intentionally omits the
  `dom` lib (`"lib": ["es2022"]`) for the rest of the workspace (server/RSC
  code has no DOM). A Playwright spec's `page.evaluate(() => ...)` callback
  runs in the _browser_, so referencing `getComputedStyle`/`document`
  inside it fails `tsc --build` with "cannot find name" even though the
  code runs fine — fix by adding `"lib": ["es2022", "dom"]` as a
  `compilerOptions` override scoped to `apps/marketing-e2e/tsconfig.json`
  only, not the shared base config.
- `firefox`/`webkit` Playwright browser binaries are not installed in this
  sandbox (only chromium) — `nx e2e` runs all 3 configured projects
  regardless of a `--project=chromium` CLI flag (nx doesn't forward it to
  the underlying `playwright test` command the way `--grep` does). Confirm
  a failure is a pre-existing environment gap, not your change, by running
  the _existing_ `example.spec.ts` the same way — if it fails identically
  on firefox/webkit and passes on chromium, the gap predates your work.

**Patterns:**

- Scroll-reveal + reduced-motion shape reused across every new organism
  (`how-it-works-section.tsx`, `team-section.tsx`, `install-section.tsx`):
  collect target refs into an array via a callback ref
  (`cardRefs.current[i] = el`), then in `useIsomorphicLayoutEffect`,
  `gsap.matchMedia()` with the same `reduceMotion`/`allowMotion` pair as
  the hero (NA-16) — reduced branch does `gsap.set(targets, {autoAlpha:1,
y:0})` immediately (no ScrollTrigger created at all); normal branch does
  `gsap.from(targets, {autoAlpha:0, y:24, stagger, scrollTrigger:{trigger,
start:'top 75%', once:true}})`. `once: true` on the ScrollTrigger (not
  `toggleActions`) is the simplest way to satisfy "plays once per page
  view" for a `.from()` reveal.
  Reusable regression-test shape for this pattern (see
  `specs/how-it-works-section.spec.tsx` etc.): mock `gsap.matchMedia().add`
  to compute `conditions` from a stubbed `window.matchMedia` and only
  invoke the handler if any condition matches (mirrors GSAP's real
  contract); one test asserts `gsap.set(...autoAlpha:1,y:0)` fires and
  `gsap.from` never gets called under `reduceMotion`; another asserts
  `gsap.from` fires with a `scrollTrigger: {once: true}` object under
  `allowMotion`.
- Looping GSAP timeline gated by scroll visibility, for a "stream once
  then repeat forever while on-screen" effect (the terminal's simulated
  `/auto` run, AC2): `gsap.timeline({repeat:-1, repeatDelay, scrollTrigger:
{trigger, start, end, toggleActions:'play pause resume pause'}})`, then
  `.from(lineEl, {...}, i===0 ? 0 : '+=gap')` per line. Repeat naturally
  re-applies each `.from()`'s start values on every loop (no manual
  `.set()` reset needed between cycles) — GSAP re-renders the timeline's
  start state whenever local time wraps back to 0.
- React 19: use `ref` as a plain destructured prop (`function Card({...,
ref}: Props & {ref?: Ref<HTMLDivElement>})`) instead of `forwardRef` —
  confirmed working through a list `.map()` with a per-item callback ref
  assigning into a parent-owned `useRef` array.

## 2026-07-10 — Story NA-21 — review-fix: GSAP clearProps residue, StatCounter prop leak, invisible specs, pipeline overflow

**Learnings:**

- The reduce-motion "no-op" fix (finding: `gsap.set(targets, {autoAlpha:1,
y:0})` in the `reduceMotion` branch is unnecessary residue when nothing
  ever hid the elements in CSS) is a genuine no-op: just `if (reduceMotion)
return;`. Verified empirically per component — only fix it where the
  target really is visible-by-default; `stat-counter.tsx`'s reduce branch
  sets `numberEl.textContent` directly (real logic, not GSAP residue) and
  was correctly left alone.
- `clearProps` only matters for a _settle-once_ reveal (`gsap.from(...,
scrollTrigger:{once:true})`) whose target has a CSS `:hover` rule on the
  same tweened property (transform). A perpetually-looping timeline
  (`repeat:-1`, like the terminal's streaming lines) never "settles" the
  same way and had no `:hover` rule on the tweened lines — adding
  `clearProps` there would be a no-op refactor for its own sake; documented
  why it's absent instead of adding it reflexively everywhere `gsap.from`
  appears.
- Extracted `use-scroll-reveal.ts` (`useScrollReveal` hook) to unify the
  ~40-line matchMedia reduce/allow scaffold across how-it-works-section,
  team-section, and install-section. **Pitfall avoided:** the natural
  first draft read `sectionRef.current` / `cardRefs.current` as plain
  _values_ at the hook-call boundary (component render time) and passed
  them into the hook's options object — but refs from the same render pass
  aren't attached to the DOM yet during render (only after commit, before
  layout effects run), so a naive extraction would silently break with a
  stale `null` trigger on mount. Fixed by making the hook accept
  `getTrigger: () => ...` / `getTargets: () => ...` **lazy accessor
  functions**, evaluated only inside the internal `useIsomorphicLayoutEffect`
  callback (i.e. after commit) — not at the call site. Any shared hook that
  wraps ref values must take accessors, never resolved `.current` values,
  if it defers reading them to an effect.
- `StatCounterProps = Stat` vs `Omit<Stat, 'id'>`: TSX spread props
  (`{...stat}`) do **not** trigger excess-property-checking, so the broken
  `id`-required type was only ever caught at _spec_ render call sites
  (`<StatCounter value={11} label="x" />` with no `id`), not at the real
  call site in how-it-works-section.tsx. Don't assume a prop-type bug is
  invisible everywhere just because the production call site compiles.

**Pitfalls:**

- `apps/marketing/tsconfig.spec.json` had `"references": [{"path":
"./tsconfig.json"}]` pointing at a config with `"noEmit": true` — this
  combination is fundamentally broken for direct `tsc --build` (TS6310
  "referenced project may not disable emit") and even for a plain `tsc -p`
  once composite-mode kicks in (TS6305 "output file has not been built").
  This is _why_ Nx's `@nx/js/typescript` plugin silently never generates a
  `typecheck` target for `@nightshift-ai/marketing` at all (confirmed via
  `nx show project @nightshift-ai/marketing --json` — no `typecheck` key,
  with or without a cold `nx reset`) — unlike `packages/ui` (whose
  `tsconfig.spec.json` correctly references an emit-capable
  `tsconfig.lib.json`) or `apps/marketing-e2e` (whose `tsconfig.json` has
  no "references"/noEmit conflict at all). **`pnpm nx run-many -t
typecheck` never touches the marketing app** — it only runs for
  `@nightshift-ai/ui` and `@nightshift-ai/marketing-e2e`. To actually
  verify marketing's spec types, run `tsc -p apps/marketing/tsconfig.spec.json`
  directly (or via `rtk proxy pnpm exec tsc -p ...` — the rtk wrapper's
  summarized "No errors found" can be **wrong/stale** relative to the full
  log; cross-check `~/Library/Application Support/rtk/tee/*.log` or use
  `rtk proxy` to get the real, unfiltered tsc output before trusting a
  clean result).
- Fixed the tsconfig.spec.json structure by making it `"extends":
"./tsconfig.json"` (inherits `paths`, `lib`, `esModuleInterop`,
  `resolveJsonModule` — extends does **not** inherit `"references"`, so
  the noEmit conflict disappears) instead of extending
  `../../tsconfig.base.json` directly, dropping the broken `references`
  entirely, and widening `include` to real `src/**/*.{ts,tsx,js,jsx}` (not
  just `*.spec.*`) — without this widening, importing `../src/...` from
  `specs/` without project references throws TS6307 ("file is not listed
  within the file list of project"; TS requires every transitively
  imported file to match an `include` pattern when there's no reference
  graph). Also had to override `"rootDir": "."` — inherited from
  `tsconfig.json` as `"src"`, which rejects `specs/**` and root-level
  `jest.config.cts` with TS6059 once those live outside `rootDir`.
- The pipeline responsive fix used a plain CSS media query
  (`max-width: 800px`, matching the existing sibling breakpoint in
  `how-it-works-section.module.css`), not the nightshift-design DS
  Pipeline component's `orientation` prop pattern — this repo's
  `pipeline-stage.tsx` is a hand-built recipe, not an import of the DS
  component, so there's no `orientation` prop to thread through; the CSS
  breakpoint achieves the same "stack vertically below ~800px" result the
  DS's `orientation="vertical"` layout describes.

**Patterns:**

- Playwright regression guard for the "GSAP inline-style residue blocks
  CSS :hover" bug class: after `scrollIntoViewIfNeeded()`, poll
  `{computed: getComputedStyle(el).transform, inline:
(el as HTMLElement).style.transform}` until it equals `{computed:
'none', inline: ''}` — checking computed transform alone isn't enough,
  since an inline `transform: translate(0,0)` computes to the same
  identity matrix as no transform at all but still wins every future
  `:hover` cascade.
