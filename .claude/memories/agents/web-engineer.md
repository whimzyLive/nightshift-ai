# web-engineer memory

## 2026-07-10 — Story NA-22 — review-fix pass (Tailwind @source, e2e, admin fonts, dep hygiene, CMS labels, migration docs)

**Learnings:**

- Tailwind v4's automatic source detection does **not** follow symlinked
  workspace packages under `node_modules` (pnpm workspace `link:`/`workspace:*`
  symlinks) — `packages/ui`'s classes were silently tree-shaken from the built
  CSS even though `packages/design-system/src/theme.css` (which `apps/marketing`
  imports) sits right next to it in the monorepo. Fix: an explicit
  `@source '../../ui/src';` directive in `theme.css`, relative to the CSS
  file's own location, not the consuming app. Verify by grepping the actual
  **built** `.next/static/chunks/*.css` for a class that only exists in
  `packages/ui` (e.g. `.bg-surface-terminal`) — grep only the first CSS chunk
  file found is not enough, Next.js Turbopack splits Tailwind output across
  several hashed chunk files; grep `*.css` (glob) across all of them.
- Declaring a new direct `dependencies` entry in a workspace package's
  `package.json` for a package that's already resolved in `pnpm-lock.yaml`
  transitively (here: `tailwindcss@4.3.2`, already pulled in by
  `@tailwindcss/postcss`) still requires `pnpm install` to add the
  **importer** entry to the lockfile — but the diff stays minimal (a few
  lines under that one importer, no version bumps elsewhere) because the
  package is already resolved at that exact version. Don't skip `pnpm
install` here out of over-caution about "modifying the lockfile" — a
  reviewer finding that explicitly asks you to declare a dependency is the
  explicit instruction the no-lockfile-edits guardrail carves an exception
  for; just verify the diff is importer-only before staging.
- Payload's generated `(payload)/layout.tsx` (`RootLayout` from
  `@payloadcms/next/layouts`) accepts an `htmlProps` prop
  (`React.HtmlHTMLAttributes<HTMLHtmlElement>`) that gets spread directly
  onto the `<html>` element it renders — this is the supported extension
  point for adding a `next/font` `.variable` className to the admin's
  `<html>` without hand-editing the "DO NOT MODIFY" generated markup itself
  (only the props passed into `<RootLayout>` change). Confirmed by reading
  `@payloadcms/next/dist/layouts/Root/index.js` directly rather than
  guessing. A reviewer finding can explicitly sanction editing a
  generated/do-not-hand-edit file for one narrow, supported purpose — but
  prefer the narrowest supported extension point (`htmlProps`) over a
  free-form rewrite of the file.
- A local dev Postgres provisioned via Payload's schema **push** mode (not
  migrations) does not automatically pick up a new field added to a
  `GlobalConfig` — `payload generate:types` only reads the config (no DB
  schema check), so types regenerate fine, but the next `next build`
  prerender fails at query time with `column ... does not exist`. Fix for a
  throwaway local dev DB: `ALTER TABLE <table> ADD COLUMN IF NOT EXISTS
<snake_case_field> <type>;` directly via psql (matches what push-mode would
  have done) rather than writing a real migration for a single-field
  addition. Confirmed via the exact `column site_settings.github_label does
not exist` error from `next build`'s prerender of a page that calls
  `payload.findGlobal`.
- Regenerating `payload-types.ts` via
  `pnpm --filter @nightshift-ai/marketing exec payload generate:types`
  reformats **the entire file** to Payload's own (non-prettier) line-wrap
  style, producing a much larger diff than the actual schema change (e.g. 44
  lines changed for a 1-field addition). Run `pnpm exec prettier --write
apps/marketing/src/payload-types.ts` immediately after regenerating —
  collapses the diff back down to just the real change (2 lines for a
  1-field addition here) and matches what the repo's own lint-staged hook
  would do on commit anyway.
- When two components render an identical CMS-sourced literal for the same
  destination (Hero's and FinalCta's "Star on GitHub" buttons, both linking
  `siteSettings.githubUrl`), the reviewer-preferred fix per "avoid schema
  changes if wiring existing fields suffices" is to **thread the one
  existing field through as an extra prop** (`home.hero.starCtaLabel` passed
  into `<FinalCta starCtaLabel={...}>`) rather than adding a duplicate field
  to the second component's own CMS group. Only add a new Payload field when
  no existing field actually carries the needed copy (e.g. `SiteHeader`'s
  short nav "GitHub" label is genuinely distinct from the "Star on GitHub"
  CTA copy — that one did need a new `githubLabel` field on `SiteSettings`).
- `packages/ui`'s `InstallSnippet` was missing the `label` prop the
  canonical nightshift-design source component (`.claude/skills/nightshift-design/components/core/InstallSnippet.jsx`
  / `.d.ts`) already documents (`label` optional uppercase mono caption) —
  worth diffing a ported `packages/ui` primitive against its canonical
  `.claude/skills/nightshift-design/components/` source when a CMS field
  clearly wants to feed a prop the ported component doesn't yet expose,
  rather than assuming the port is 1:1 complete.

**Pitfalls:**

- Don't grep only the first CSS file `find` returns when verifying a
  Tailwind build-output fix — Next.js/Turbopack can split the compiled CSS
  across multiple hashed chunk files, and the class you're checking for may
  not be in the first one found (it wasn't, here — `.bg-accent` and
  `.bg-surface-terminal` were both in a _different_ 30KB chunk, not the
  288KB one that came up first alphabetically).

**Patterns:**

- Playwright e2e spec pinned to CMS-driven content that can legitimately
  render as empty strings (no seeded CMS doc) should assert on **structural
  landmarks** (`page.getByRole('banner'|'main'|'contentinfo')` +
  `response.ok()`) instead of visible copy — resilient to both an empty CMS
  and to future copy changes, while still catching a genuinely broken page.

## 2026-07-10 — Story NA-22 — Create Marketing Website (design-system + ui + full CMS-driven site)

**Learnings:**

- Worktree branch mismatch: my dispatch worktree's own branch
  (`worktree-agent-<id>`) can be **behind** `<BRANCH_PREFIX>/<STORY-KEY>` on
  origin even though the orchestrator said the branch "is checked out in
  your worktree" — `git checkout <branch>` fails because that branch is
  checked out in the _primary_ worktree, not mine. Fix: `git fetch origin &&
git merge <branch> --ff-only` in my own worktree branch (safe, no new
  branch, no touching the other worktree) — confirmed the ff-only merge
  brought in a commit (`docs(plan): ...`) my worktree was missing.
- lint-staged's `prettier --write --ignore-unknown` runs on **every commit**
  and will reformat vendored/"must stay byte-identical" files (long CSS
  custom-property values get line-wrapped) — this silently desyncs a
  vendored-token parity check the moment you commit, even though the file
  was byte-identical when written. Fix: add the vendored directory to
  `.prettierignore` (`packages/design-system/src/tokens/*.css` this story),
  then re-vendor and re-verify. Always re-diff vendored files against their
  canonical source (and re-run the parity check) immediately after the
  first commit that touches them — don't trust the pre-commit state.
- Tailwind v4 CSS-first `@theme`: when two vendored token files both declare
  the same custom property (canonical `typography.css` hardcodes literal
  `--font-sans: 'Inter', ...`; a new `fonts.css` sets `--font-sans:
var(--font-inter), ...` for next/font wiring), **CSS import order in
  `theme.css` decides which one wins** — later `@import` wins for `:root`
  rules of equal specificity. A plan/spec's prescribed import order can
  silently defeat its own "fonts self-hosted via next/font" decision if the
  next/font-linked file isn't imported _last_. Verify by grepping the built
  `.next/static/chunks/*.css` for the final `--font-sans:` declaration
  after `next build`, don't assume from source order alone.
- `nx sync` needs to be run **twice** to converge in this workspace — the
  first invocation both reports "workspace is out of sync" _and_ applies
  the fix in the same run; only the second invocation reports "already up
  to date". Don't treat the first run's warning as a failure.
- A shared Postgres container from another worktree/session can already be
  listening on `localhost:5432` (`docker ps`/`docker info` themselves may
  hang/timeout in this sandbox even when the container is reachable) — try
  `psql`/`nc` against the default docker-compose creds
  (`postgresql`/`password123`/`nightshift`, see
  `apps/marketing/docker-compose.yml`) before assuming you must run
  `local-start` yourself. Check `\dt` for existing relations first so you
  know whether you're reusing a clean or dirty DB.
- Confirms and extends the NA-16 "static prerendering needs a migrated
  schema" pitfall below: for this story the spec explicitly wants **ISR**
  (`export const revalidate = 60`), not `force-dynamic` — so the correct
  fix when `next build` fails on `relation "..." does not exist` is to
  **apply the migration locally** (`payload migrate`) before building, not
  to add `dynamic = 'force-dynamic'`. Only reach for `force-dynamic` when
  the spec actually calls for per-request rendering; check which one the
  spec/plan wants before "fixing" a build failure.
- `@payloadcms/richtext-lexical/lexical` subpath is `export * from 'lexical'`
  — confirmed via `dist/lexical-proxy/lexical.d.ts` — so
  `SerializedEditorState` (and any other `lexical` package export) is
  available from it directly; no need to import from the `lexical` package
  itself or the richtext-lexical package root.
- Payload admin theming (`(payload)/custom.scss`): almost everything the
  admin paints from (`--theme-bg`, `--theme-text`, `--theme-input-bg`,
  borders) derives from a `--theme-elevation-0..1000` scale defined in
  `@payloadcms/ui/dist/scss/colors.scss`, which itself derives from
  `--color-base-0..1000`. Overriding just the elevation scale (+ the direct
  aliases `--theme-bg`/`--theme-text`/`--theme-input-bg`/`--theme-border-color`)
  in a plain `:root` block repaints the whole admin without touching
  Payload's own SCSS. Payload also reuses `--theme-success-500` for focus
  rings and several "primary" affordances (`vars.scss`
  `$focus-box-shadow`) — repurposing it as the brand accent color (rather
  than leaving it green) is the standard way to get a single accent color
  through the admin when Payload has no dedicated "accent" token.
- `jest.mock('./module')` **without a factory** still `require()`s the real
  module to build the automock shape — if that module (transitively)
  imports an ESM-only package your babel-jest transform ignores in
  `node_modules` (e.g. `payload`), automocking throws `Cannot use import
statement outside a module` even though you never call the real
  implementation. Fix: always pass an explicit factory,
  `jest.mock('./module', () => ({ fn: jest.fn() }))`, when the module being
  mocked has heavy/ESM transitive imports.

**Pitfalls:**

- Don't extrapolate "spirit" fixes (reordering CSS imports, adding
  `.prettierignore` entries, adding a Jest factory) without also re-running
  the exact verification command the plan specifies — in every case above
  the deviation was necessary because the literal plan snippet, taken
  verbatim, actively failed its own stated "Expected: PASS" outcome in this
  environment.

**Patterns:**

- When a plan's own file list omits a config file a later step's command
  needs (e.g. Task 1 asked for `pnpm nx test design-system` but didn't list
  a `jest.config.cts` in Files), add the minimal config mirroring the
  nearest sibling project's config (`packages/ui/jest.config.cts`) rather
  than skipping the verification step — the plan's steps are the source of
  truth over its own file inventory when they conflict.

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
