## 2026-07-23 — Story NA-69 — 11 restrained motion beats (Foundation + Tiers B/C/A/D)

**Learnings:**

- Consolidating a re-declared helper into a single `@nightshift-ai/ui` export
  (`EASE_OUT`, `prefersReducedMotion()`) is a pure behaviour-preserving
  refactor validated by the _existing_ per-component specs staying green
  with zero spec edits — no new test needed for the migration itself, only
  for genuinely new primitives. `useInViewOnce()` needed the opposite
  treatment (new hook, new spec) since it's new surface, not a
  re-declaration: it returns `{ ref, inView, immediate }` — `immediate`
  distinguishes "became true via the reduced-motion/no-IntersectionObserver
  degrade" from "became true via a real viewport entry," which `CountUp`/
  `RollingNumber` both need to decide "skip the animation, snap to final"
  vs "play it." A bare `inView` boolean alone can't make that distinction
  since both paths set it `true`.
- Framer Motion's `pathLength` on an SVG `motion.path` compiles to
  `stroke-dasharray="X 1"` (not a `pathLength` DOM attribute check) —
  `"0 1"` is undrawn, `"1 1"` is fully drawn. Discovered by a throwaway
  `console.log(path.outerHTML)` spike rather than guessing the DOM shape;
  worth doing this for any new Motion SVG primitive before hand-writing
  assertions.
- `motion.span`'s `x`/`y` style motion values render as `style.transform`,
  but a component with an _unset_ motion value (both `x`/`y` at their
  default 0, e.g. `MagneticCta` before any pointer move) serializes
  `style.transform` as the literal string `"none"`, not `""` or
  `"translateX(0px) translateY(0px)"` — same throwaway-spike-first approach
  resolved this before writing the reduced-motion assertion.
- A `whileTap`/spring-driven DOM style update (`MagneticCta` pointer-follow,
  `ControlSection`'s `whileTap={{scale:0.96}}`) is **not necessarily
  reflected synchronously** after `fireEvent.pointerDown`/`pointerMove` even
  inside RTL's `act()`-wrapped `render()` — needs `waitFor`, and needs a
  **generous** timeout (bumped to 3000ms) when the whole `nx test` suite
  runs many files in parallel workers under CPU contention, or the same
  assertion that passes reliably in isolation flakes when run alongside
  other spec files. Isolate-vs-full-suite flakiness on a real (not mocked)
  Motion transition is a legitimate reason to widen a `waitFor` timeout, not
  a sign the test is wrong.
- Wrapping a _live, post-mount_ state change (e.g. `TeamPreview`'s hover
  `active` state) in `AnimatePresence mode="wait"` genuinely introduces an
  async gap before the new keyed child's content lands — existing
  synchronous `fireEvent.mouseEnter` → immediate `expect(...)` assertions
  broke and needed `await waitFor(...)`. Contrast: `argument-rail.spec.tsx`'s
  established `AnimatePresence mode="wait"` usage was never actually
  exercising this async path in its existing tests (its `active` value came
  from a mocked hook fixed **before** `render()`, never changed **after**
  mount) — don't assume an existing AnimatePresence pattern's test file
  proves the post-mount-transition case works synchronously; check whether
  its tests ever actually change the key after mount.
- `useScroll({ target, offset })` (Framer's per-element scroped scroll
  tracking, used for `PipelineStrip`'s A2 5-band index) has **no prior
  tested precedent in this codebase** — the existing `scroll-progress.tsx`
  (why-sdlc gate rail) instead uses whole-page `useScroll()` +
  `useMotionValueEvent` + manual `getBoundingClientRect()` thresholds
  against `document.querySelectorAll`. Both are legitimate Framer patterns;
  chose the `{target}` form because the plan named it explicitly for A2,
  and confirmed via a real test (mocked `getBoundingClientRect` +
  `fireEvent.scroll`) that it doesn't throw and settles to a valid
  stage-status combination in jsdom — don't assume a hook not yet exercised
  elsewhere in the repo is unsafe; spike it with a real render first.
- Framer Motion's `useReducedMotion()` (the second established latch,
  `night-sky.tsx`-only per the shared-conventions table) is backed by a
  **module-level singleton** in `motion-dom` (`initPrefersReducedMotion`/
  `hasReducedMotionListener.current`), not a per-component `matchMedia`
  read — meaning, unlike the `prefersReducedMotion()` function pattern,
  there's no reliable way to toggle it per-test within one Jest module
  registry (first call wins, memoized). This is _why_ `night-sky.spec.tsx`
  had zero reduced-motion tests before this story, and why the new A1 tests
  only cover the dawn-backdrop's variant-gating and token usage, not an
  actual reduced-motion assertion — a real, structural testing gap
  inherited from the library, not something worth spending further budget
  forcing via `jest.resetModules()` gymnastics for one story.

**Pitfalls:**

- An `eslint-disable-next-line react-hooks/exhaustive-deps` comment on a
  deliberately-`[]`-deps effect (`useInViewOnce`'s mount-once observer)
  fails oxlint with "Definition for rule ... was not found" — this repo's
  ESLint config has no `react-hooks` plugin registered at all (confirmed via
  the lint failure, not the config file). Drop the disable comment entirely
  and just leave an explanatory prose comment instead; every other
  intentionally-partial dependency array in this codebase (e.g.
  `terminal.tsx`'s mount effects) already does this with no lint suppression
  needed.
- `pnpm nx build marketing` remains the only real `tsc`-equivalent signal
  (no repo `typecheck` target, per prior stories' findings) — ran it after
  all five task-group commits as an extra safety net beyond `lint`/`test`,
  since several of this story's changes (new `layoutId`/`useTransform`/
  `useVelocity` usages) are the kind of Motion-API surface where a typo in
  a generic parameter wouldn't necessarily fail Jest's babel transform but
  would fail a real type-check.

**Patterns:**

- Task-group-scoped commits (Foundation → B → C → A → D, one commit each)
  made the "did the shared hook/const actually get consumed everywhere it
  was supposed to" self-review trivial — `git show <task-group-commit>
--stat` cleanly maps to the plan's own task-group boundaries.
- For a brand-new Motion primitive whose committed DOM shape isn't obvious
  from the source alone (SVG `pathLength`, a spring's `style.transform`,
  digit `stroke-dasharray`), write the test with a throwaway
  `console.log(el.outerHTML)`/`JSON.stringify(el.style.X)` assertion first,
  run it once to observe the real value, then replace the console.log with
  the real assertion — faster and more honest than guessing the shape from
  Framer Motion's source/docs.

## 2026-07-13 — Brand the Payload admin (logo, icon, theme)

**Learnings:**

- `admin.components.graphics.Icon`/`.Logo` in `payload.config.ts` are real
  fields (`payload/dist/config/types.d.ts` — `CustomComponent`), path format
  `'/relative/to/importMap.baseDir/file#ExportName'`. `baseDir` here is `src/`,
  so `apps/marketing/src/components/admin/icon.tsx` exporting `Icon` becomes
  `'/components/admin/icon#Icon'` — filename kebab-case per this repo's
  convention, export name PascalCase to match Payload's own graphics-slot
  contract. `npx payload generate:importmap` (or `next build`, which calls it
  internally) picks this up with zero extra config; its "No new imports found,
  skipping writing import map" console line is stale/misleading — the file
  updates anyway, always verify via `git diff` on `importMap.js`, not the CLI
  text.
- Payload's admin CSS theming surface is narrower than it looks: almost
  everything (bg, text, input bg, borders, checked-state color, focus rings,
  dropzone drag-border, auth "confirmed" border) derives from
  `--theme-elevation-0..1000` plus `--color-success-500`/`--theme-success-500`
  (verified by grepping the installed `@payloadcms/ui/dist/**/*.scss`, not the
  project skill — the `payload` skill doc has no admin-theming reference at
  all). There's no independent "brand/accent" custom property — repurposing
  the success token for the terracotta accent is the only documented lever
  that hits buttons/checked-inputs/focus without touching Payload's own SCSS.
  Primary buttons read `--theme-elevation-800` for their bg, which is also
  reused all over as a text/border color — overriding it to terracotta directly
  would repaint far more than buttons and risks contrast breaks, so it's set to
  a light moonlight tone instead (matches the brand's moonlight-on-night look)
  rather than forcing every primary button terracotta.
- This exact `custom.scss` (elevation scale + `--theme-bg/-text/-input-bg/-border-color`
  aliases + success-token accent) had already been authored once before on an
  unmerged `feat/NA-22` worktree branch (commit `8f15445`, refined in
  `5a8dba7`) — found via `git log --all -- '.../custom.scss'`. Confirmed its
  hex values still match the canonical `.claude/skills/nightshift-design/tokens/colors.css`
  scale exactly before reusing it; dropped its `--font-body`/`--font-mono`
  overrides since this dispatch's brand facts didn't ask for admin typography
  and the `--font-inter`/`--font-jetbrains-mono` vars those overrides pointed
  at aren't wired into `(payload)/layout.tsx` on this branch (that self-hosting
  change lived only on the same unmerged branch).
- `git log --all -- <path>` is a cheap way to check whether a "new" file this
  dispatch is about to create was already built and abandoned/orphaned on some
  other branch — worth doing before hand-authoring CSS/config from scratch
  when a plausible prior attempt could exist.

**Pitfalls:**

- `apps/marketing/next-env.d.ts` churns on every `next build` (quote-style
  only, `'...'` → `"..."`) — `git checkout --` it before staging, same
  established finding as prior stories.

**Patterns:**

- New Payload admin custom components (graphics, custom views, etc.) belong
  under `apps/marketing/src/components/admin/` — plain RSC, static string ids
  instead of `useId` (no `'use client'` needed), geometry ported verbatim from
  the canonical `packages/ui/src/lib/nightshift/logomark.tsx` source rather
  than re-derived.

## 2026-07-13 — PR #97 review-fix round — 8 small accepted findings across scroll-progress/terminal/nav-bar/jest.setup/cta-kicker/argument-rail

**Learnings:**

- The reduced-motion "latch in state via a post-mount effect" pattern (already
  established for `terminal.tsx`/`phrase-marquee.tsx`) needed to be applied to
  two more render-time `prefersReducedMotion()` call sites this round:
  `cta-kicker.tsx` (one call) and `argument-rail.tsx` (four calls — one inside
  `GateNode`, three inside `ArgumentRail`'s `AnimatePresence` crossfade).
  Reading matchMedia during render (not inside `useEffect`) is an SSR/hydration
  mismatch risk on every Motion `initial`/`animate` prop that branches on it —
  worth grepping for this specific shape (`const reduced = prefersReducedMotion()`
  as a bare top-of-body `const`, not inside `useEffect`) across a whole
  component tree, not just the file a reviewer flagged, since the same author
  pattern tends to repeat within one PR.
- For a helper called from a child component (`GateNode`'s own `pulse` calc),
  the fix is to latch the boolean once in the parent and thread it down as an
  explicit prop (`reduced: boolean` added to `GateNodeProps`) rather than
  duplicating the effect/state pair in the child — keeps `matchMedia` reads to
  exactly one per component tree per mount.
- `argument-rail.spec.tsx`/`cta-kicker.spec.tsx` needed **no changes** for this
  fix — neither spec mocks `matchMedia` to the reduced-motion branch or asserts
  render-time timing, so latching the read behind a `useEffect` (which fires
  synchronously enough after the initial render in RTL's `render()` for the
  assertions in these specs, which only check text/attribute content, not
  animation props) left both suites green with zero spec edits. Don't assume a
  hydration-mismatch fix always requires a test update — check what the
  existing spec actually asserts first.
- The non-breaking-space fix (`line.text || ' '` → `line.text || ' '` in
  `terminal.tsx`) is invisible in a normal diff view/prompt text (NBSP and a
  regular space render identically in most editors/terminals) — verified the
  edit actually landed the `\xa0` byte (not a plain `0x20`) via a `python3`
  `repr()`/`ord()` check on the file content before trusting the `Edit` tool's
  success message. Worth this extra verification step any time a fix's
  before/after snippets are visually indistinguishable.
- `git status` at dispatch start already showed `apps/marketing/src/payload-types.ts`
  modified (stale churn from a prior session's build, unrelated to this PR's
  scope) — by the time this round's own `pnpm nx build marketing` finished, that
  file no longer showed as modified (regenerated back to match committed
  content), so nothing needed discarding there this round. `next-env.d.ts` did
  churn as expected (established NA-32/NA-36 finding) — `git checkout --` it
  before staging, same as always.

**Patterns:**

- Renaming a component identifier for brand casing (`GithubMark` →
  `GitHubMark`) is a pure find-and-replace across its one declaration + one
  JSX usage site in the same file — no export from the file, so no other
  file in the repo needed touching. Confirmed via reading the whole file
  first rather than grepping repo-wide for a name that turned out to be
  file-local.

## 2026-07-12 — refactor/motion-gsap-animations follow-up — visual-fidelity pass against the design handoff HTML

**Learnings:**

- A user-attached "standalone" HTML export (`nightshift Landing (standalone).html`)
  looked like plain static markup at a glance but was actually a JS-bundler
  artifact — the real HTML lived escaped inside a giant JS string literal
  (`\"...\"`, `/` for `/`). Two lines in the file were 549K/173K chars.
  `grep -o 'id="..."'` against the raw file found nothing; extracting the
  quoted string span (find the opening `"` before `<!DOCTYPE`, scan forward
  respecting `\`-escapes to the matching closing `"`, then `json.loads()` it
  to unescape) turned it into normal readable HTML. Confirmed by its own
  `id="..."` markers (`top`, `proof`, `problem`, `how-it-works`, `workflow`,
  `agents`, `faq`, `install`, plus two un-id'd `data-screen-label="Why
different"`/`"Control bridge"` sections) that it covers **only the home/
  landing page** — not `/faq`, `/team`, or `/why-sdlc` — despite a request
  phrased as "all pages."
- Systematically diffing every home `<section>` root's inline `style`
  (background/border/padding) against the reference caught two classes of
  real, pre-existing drift that had survived multiple "verbatim from the
  design handoff" component builds:
  1. `phrase-marquee.tsx` used `--surface-terminal` background + `--text-dim`
     text — the reference's `.ns-marquee` is a **solid `--terra-500` band**
     with `!important`-forced `#f5f3ef` text (= `--text-on-accent`, the
     correct semantic token for text-on-accent-background) and asymmetric
     `--terra-400`/`--terra-600` top/bottom borders, plus a
     `.ns-marquee:hover .ns-marquee-track{animation-play-state:paused}`
     interaction with no equivalent in the migrated code at all.
  2. Three non-full-bleed sections (`day-night-workflow.tsx`,
     `why-different.tsx`, `faq-preview.tsx`) each carried their own literal
     `28px` horizontal padding **in addition to** `<main>`'s
     `className="... px-7"` (28px) in `(frontend)/layout.tsx` — double
     padding (56px vs the reference's 28px). `hero.tsx` is the one section
     that gets this right already (explicit `0` horizontal, deferring to
     `<main>`'s `px-7`) — it's the template to match, not an outlier. The
     tell: every OTHER home section either (a) uses the `left-1/2 right-1/2
-mx-[50vw] w-screen` full-bleed escape and therefore correctly needs
     its own 28px (it's opted out of `<main>`'s padding), or (b) stays
     contained and must therefore use `0` horizontal padding. Grepping for
     files with a literal `28px` padding value but _no_ `-mx-[50vw]` class
     found exactly the 3 buggy ones (plus 2 false-positive `margin: 28px`
     hits that weren't the padding shorthand — verified each match's
     context, not just presence).
- Discovered mid-task that **a concurrent process using the identical
  Claude-Session ID was independently working the same branch** (`git log`
  showed `e165158`/`d9649a4`, already pushed to `origin/refactor/motion-gsap-animations`,
  with the exact scope of this dispatch — marquee/team-preview/control-section
  — plus an out-of-scope-for-this-dispatch why-sdlc + faq-row Motion pass
  and a `global.css` `ns-*` keyframe cleanup). `git diff HEAD` against my
  own already-written `control-section.tsx`/`team-preview.tsx` came back
  **empty** — the concurrent commit's content was byte-identical to what I'd
  independently produced from the same brief, so nothing was lost, just
  already captured. That process had also already opened PR #97 for this
  branch — checked `gh pr list --head <branch>` before creating a new PR to
  avoid a duplicate.
- `pnpm nx build`/`test` regenerate three unrelated tracked files as a side
  effect: `apps/marketing/next-env.d.ts` (Next.js flips
  `.next/dev/types/routes.d.ts` vs `.next/types/routes.d.ts` depending on
  dev-vs-build mode — the file's own header says "should not be edited"),
  `(payload)/admin/importMap.js`, and `payload-types.ts` (Payload
  admin-panel/type codegen, non-deterministic plugin-discovery ordering).
  None of these are related to any actual code change — `git checkout --
<file>` them back to HEAD before every commit in this repo, every time,
  regardless of which task is running; don't let build-tool churn ride
  along in a commit's diff.

**Patterns:**

- When asked to verify "visual appearance ... as per attached html" and the
  attachment turns out to be an opaque bundle, don't give up at "can't
  parse it" — extract the escaped-string payload with a small `python3`
  heredoc (`json.loads` on the located quoted span) rather than treating it
  as unparseable; the reference author almost certainly exported this from
  a real browser DOM, so the escaped payload is complete, well-formed HTML.
- A user's direct mid-turn message is real authorization that supersedes an
  earlier agent-issued dispatch constraint (e.g. "do not commit or push")
  for the _scope of what the user just asked_ — per this role's own system
  prompt, only agent messages are barred from granting that kind of
  permission; the actual human's message is not. Still worth pausing to
  check `gh pr list` for an existing PR on the branch before opening a new
  one, especially in a multi-agent pipeline where another process may have
  already acted on the same branch.

## 2026-07-12 — Story NA-39 — wire SEO meta, JSON-LD, and llms.txt (non-visual)

**Learnings:**

- `@payloadcms/richtext-lexical/plaintext` (the `convertLexicalToPlaintext`
  export the spec explicitly names) ships plain ESM with no CJS build —
  same failure mode as the already-documented `/react` subpath
  (`SyntaxError: Unexpected token 'export'` under Jest). Same fix as the
  established convention: `jest.mock('@payloadcms/richtext-lexical/plaintext',
() => ({ convertLexicalToPlaintext: fakeThatFlattensLeafText }))`. Because
  `faq-plaintext.ts` (which imports it) is itself imported transitively by
  every route that renders `<JsonLd>` (via `lib/seo/jsonld.ts`'s
  `buildFaqPageNode`), this mock had to be added not just to `jsonld.spec.ts`
  but to **all three** existing page specs (`page.spec.tsx`,
  `why-sdlc/page.spec.tsx`, `faq/page.spec.tsx`) alongside their existing
  `/react` mock the moment those pages started importing `buildFaqPageNode`
  — a page spec that passed before a JSON-LD-wiring task can start failing
  for a reason invisible in that spec's own diff, purely from a new
  transitive import chain. Check every consumer of a newly-wired module for
  this class of "ESM import three hops away" breakage, not just the new
  module's own spec.
- `SerializedEditorState` (from `@payloadcms/richtext-lexical/lexical`, a
  proxy re-export of the real `lexical` package's type) and the generated
  `Faq['answer']`/`Faq['homeAnswer']`/`Faq['whySdlcAnswer']` shapes in
  `payload-types.ts` are **structurally assignable with zero cast** —
  confirmed by reading `lexical`'s own `SerializedElementNode`/
  `SerializedLexicalNode` declaration files side-by-side with the generated
  type before assuming a cast would be needed (the generated type's
  `children: { type: any, version: number, [k: string]: unknown }[]` is a
  strict structural subset of `SerializedLexicalNode[]`, and the field names/
  literal unions for `direction`/`format`/`indent`/`version` match exactly).
  `pnpm nx build` (full `tsc` pass) confirmed this holds in practice — no
  `as unknown as SerializedEditorState` anywhere in the three route files or
  `FaqSchemaInput` mapping.
- `docs/gtm/site-brief.md` §3 only defines FAQPage `@id`s for the home page
  (`.../nightshift-ai#faq`) and `/why-sdlc` (`.../why-sdlc#faq`) — the
  standalone `/faq` page (built later, in NA-38, after the brief was
  written) has no brief-specified JSON-LD `@id` at all. Resolved by
  extrapolating the same established `<absolute-page-url>#faq` pattern
  `/why-sdlc` already uses (`https://github.com/whimzyLive/nightshift-ai/faq#faq`)
  rather than inventing new copy — this is a structural identifier, not
  SEO copy, so it doesn't violate the "zero new SEO copy" constraint. Flag
  any future brief gap like this the same way: extend an established
  identifier _pattern_, never author new prose.
- This is nightshift's first genuinely non-visual story — the spec itself
  states the `nightshift-design` brand/adherence gate does not apply (no
  rendered UI, no components, only `<head>` metadata + inert
  `<script type="application/ld+json">` + two `public/*.txt` files).
  Treated the override's skill list as scoped accordingly: invoked only
  `vercel-react-best-practices` (still relevant — writing/refactoring
  React/Next.js route files) and skipped `nightshift-design`,
  `tailwind-design-system`, `payload` (no collections/hooks/`payload.config.ts`
  touched, only a read-only Local API consumer already established in prior
  stories), `vercel-composition-patterns`, `atomic-design`,
  `motion-dev-animations`, `gsap-core` — none had applicable surface in this
  story's actual diff. Confirms the "applicable" qualifier in the override
  invocation instruction is meant literally, not "invoke all 8 regardless."
- `next build`'s route table shows `/` and `/why-sdlc` as `ƒ` (Dynamic, from
  the pre-existing `force-dynamic` exports) unaffected by adding `metadata`
  as a static `const` export alongside the async default export and
  `dynamic = 'force-dynamic'` — all three coexist with no `generateMetadata`
  needed, confirming the spec's own stated default (static meta, no
  request/CMS dependency) holds at the actual build level, not just in
  theory.
- No live Postgres/`curl` was available in this sandbox (`curl` itself is
  blocked by a context-mode hook redirecting to `ctx_execute`/
  `ctx_fetch_and_index`) — the plan's Task 10 "confirm `/llms.txt` and
  `/robots.txt` serve as `text/plain` from `dev`/`start`" manual check
  could only be partially discharged: `next build`'s successful static-page
  generation pass confirms `public/*.txt` is picked up and copied into the
  build output (Next's default static-file serving is a well-established,
  untunable platform behavior for anything under `public/`), but no live
  HTTP response/`content-type` header was actually observed this session.
  Flag this gap explicitly in the handoff rather than asserting the
  live-serving behavior as verified.

## 2026-07-12 — Story NA-38 — /faq full page (5 topic-grouped solid-card accordions, single-open-across-page)

**Learnings:**

- The plan's Task 2 extraction note ("the current row derives its Q.NN label
  from `index`. Keep that — home passes row index+1; the full page will pass
  `item.number`") and Task 3's literal test (`Q.01`/`Q.03` continuous across
  a group boundary) are only mutually consistent if `FaqRow`'s internal
  label formula changes from `` `Q.${index + 1}` `` to plain `` `Q.${index}` ``
  during the extraction — i.e. the `index` prop becomes the already-1-based
  display number, not a 0-based array index. Passing `item.number` straight
  through (as Task 3's illustrative code does) only produces `Q.01`/`Q.03`
  if `FaqRow` no longer adds its own `+1`. Made this change during Task 2
  (not Task 3) and updated `home/faq-accordion.tsx`'s caller to pass
  `index + 1` instead of bare `index` — confirmed behavior-preserving via
  the unmodified home accordion/preview specs staying green (same rendered
  `Q.01`/`Q.02`/`Q.03` either way for a 3-item list). Another instance of
  "the plan's literal Task N+1 test resolves an ambiguity left open in Task
  N's prose" (see the NA-34/NA-36/NA-37 entries below) — trust the test,
  adjust the earlier task's code to make both tasks' literal snippets true
  simultaneously, rather than picking one task's snippet over the other.
- `@testing-library/jest-dom` is **still** not installed in this workspace
  (re-confirmed via `grep -rln "toBeInTheDocument\|toHaveAttribute"
apps/marketing/src` returning only the plan's own not-yet-adapted spec
  text) — the NA-16 finding holds many stories later. The plan's Task 3
  literal test code uses `toBeInTheDocument()`/`toHaveAttribute(...)`
  verbatim; adapted every instance to `.toBeTruthy()` /
  `.getAttribute(...) === ...` (same assertions, no new dependency) before
  running RED, per the established convention — don't install the
  dependency for one story's test file.
- The plan's file-structure list didn't call out modifying the existing
  placeholder `app/(frontend)/faq/page.spec.tsx` (it only listed
  `page.tsx` as "Modify"), but that placeholder spec renders `<FaqPage />`
  synchronously — the moment `page.tsx` becomes `async`, that spec throws
  (same NA-16 "can't render a Promise via JSX" trap). Rewrote it following
  the `why-sdlc/page.spec.tsx` pattern (`render(await FaqPage())`,
  `jest.mock('../../../lib/faq', ...)` + the `RichText` ESM-mock) as part
  of Task 7's own TDD cycle (write the async-aware spec first, watch it
  fail against the still-placeholder `page.tsx`, then implement) — when a
  plan converts an existing page to `async` but only lists the page file
  itself as "Modify," check for and update any pre-existing spec for that
  same page too; it's an implicit dependency of the task, not out of scope.
- `getFaqPageGroups()`'s grouping loop (`Map<FaqGroup, FaqPageGroup>` keyed
  by `doc.group`, pushing to an array on first sight) needs zero special
  handling to satisfy "first-appearance order" — `payload.find({ sort:
'faqOrder' })` already returns docs in the order that makes first-appearance
  == topic-block order (seed data's `faqOrder` is contiguous per group,
  per the spec's own Data Model table), so a plain `Map` insertion-order
  iteration reproduces the handoff's 5-group order with no extra sort step.

**Patterns:**

- Reused three established patterns verbatim rather than re-deriving them:
  the `getHomeFaqs`/`getWhySdlcFaqs` try/catch-log-return-empty-sentinel
  shape for `getFaqPageGroups` (only the query shape and return type
  differ — no `where`, `limit: 100`, grouped output); the
  `(frontend)/<route>/page.tsx` single-top-level-async-boundary pattern
  (`await getFaqPageGroups()` is the only await in `FaqPage`, mirroring
  `WhySdlcPage`); and `why-sdlc/hero.tsx`'s breadcrumb + terra-glow +
  `Eyebrow` + clamp-heading structure for `FaqHero` (only the glow's
  `top/right` anchor and copy differ — handoff `faq.dc.html` anchors the
  hero glow top-right vs why-sdlc's top-left).
- A 5-group nested accordion where only ONE row across the ENTIRE tree can
  be open needs just one `useState<Id | null>` at the top-level client
  component (`FullFaqAccordion`), passed down as `isOpen={openId ===
item.id}` to every row regardless of which group card it's in — no
  per-group state, no context/provider needed, since there's only one
  reader (the component itself) and one writer (each row's `onToggle`).
  Contrast with the home preview accordion, which is intentionally scoped
  to `openIndex` local to its single card — the two components share the
  row visual (`FaqRow`) but deliberately do NOT share the open-state
  container, per the spec's explicit "do not give each group card its own
  independent open state" instruction.

## 2026-07-12 — Story NA-37 — /team org-chart page (static roster, no CMS)

**Learnings:**

- RTL's default text queries (`getByText`) resolve via `@testing-library/dom`'s
  `getNodeText(node)`, which concatenates **only direct child TEXT_NODE
  children** of a given element — it does **not** recurse into nested child
  _elements_' text. Any JSX like `<span>hello <span style={...}>world</span></span>`
  makes the outer span's own matchable text just `"hello "` (missing
  "world"), and the inner span's own text is only `"world"` — no single node
  in that tree has the full "hello world" string as its own match target,
  so `screen.getByText(/hello world/)` fails with "text is broken up by
  multiple elements" even though the rendered page visually reads correctly.
  Confirmed by reading `@testing-library/dom/dist/get-node-text.js` directly
  in `node_modules/.pnpm` rather than guessing. When a plan's fixed literal
  test asserts a getByText match against a full copy string that the design
  mock would normally split into differently-colored inline `<span>`s (e.g.
  team.dc.html's `<span style="color:accent">11</span> agents on staff`),
  render that string as **flat, unstyled text** in one element instead of
  reproducing the mock's inline color spans — this is a second, more general
  form of the "plan's literal test resolves the mock's ambiguity" pattern
  already logged for NA-34/NA-36: prefer a passing flat implementation over
  visual-parity fidelity to the raw mock's per-token coloring, and leave any
  such deviation to the QA phase's screenshot-diff pass (AC6 is explicitly
  QA-owned per the NA-37 spec, not this build phase).
- The inverse also matters: an `<li>{index + 1}. {step}</li>` with two
  expression children and one literal `". "` text child renders as **three
  sibling Text nodes**, all direct children of the `<li>` (no wrapping
  `<span>`s) — `getNodeText` concatenates all of them, so the `<li>` itself
  matches a `getByText` query against the full "1. step text" string. Use
  this shape (bare `{expr}`/literal-text siblings, no nested elements) any
  time a test needs `selector: 'li'` (or any specific element type) to match
  full composed text.
- `pnpm nx typecheck marketing` doesn't exist as a target (confirmed via
  `nx show project marketing --json` → targets are `build, dev, start,
serve-static, build-deps, watch-deps, lint, test, seed, local-start,
local-stop`) — matches project-context's "Typecheck: none configured";
  `pnpm nx build marketing` (which runs Next's own `tsc` pass internally,
  visible as "Running TypeScript ..." in its output) is the real typecheck
  gate for this app, not a separate nx target.
- `pnpm nx build marketing` with zero CMS reads on `/team` (no `lib/*.ts`
  reader, no `dynamic` export) correctly emits `○ /team` (Static) in the
  route summary, confirmed side-by-side against `/why-sdlc` and `/faq`'s
  `ƒ` (Dynamic) rows in the same build output — a clean, directly
  comparable confirmation of the static-vs-dynamic split this story's spec
  required (no `export const dynamic = 'force-dynamic'` on this page).

**Patterns:**

- All 12 `plugins/sdlc/agents/*.md` charter filenames were verified against
  the roster data by literal `ls plugins/sdlc/agents/*.md | xargs -n1
basename` before writing `roster-data.ts`'s `file` fields — cheap,
  deterministic guard against a future 404'd `charter ↗` link; worth doing
  before typing any static roster/link table by hand rather than after.
- A static server-page composing five section components with zero props
  and zero data fetch (`TeamPage`) needs no `Promise.all` top-level-async
  boundary pattern at all (contrast `/why-sdlc`'s `WhySdlcPage`) — when a
  page has no CMS/DB read, the simplest synchronous default export is both
  correct and sufficient; don't reach for the async-boundary pattern
  reflexively just because sibling pages in the same app use it.

## 2026-07-12 — Story NA-36 — /why-sdlc editorial page (gate rail + sticky crossfade pane)

**Learnings:**

- Jest was upgraded to v30 sometime after the NA-30/NA-31 entries below were
  written: `--testPathPattern=<x>` (used throughout earlier memory examples)
  now hard-fails with "was replaced by --testPathPatterns" — this repo's
  `nx test <project> -- --testPathPatterns=<x>` is the current working
  invocation. Update future single-file TDD loops to the plural flag.
- The plan's own literal test example for the gate-rail glyph states
  (`{ reached: 2, active: 1 }` → node 0 passed, node 1 pulsing current,
  nodes ≥2 idle) is **not** reproducible from the raw design mock's own
  `renderVals()` (why-sdlc.dc.html L365-377), which derives every glyph
  from `state.reached` alone (`passed = i < r; current = !passed && i
=== r`) and never reads `active` for gate styling at all — under that
  formula `reached: 2` would mark nodes 0 **and** 1 both passed, not
  current. The plan deliberately layers `active` in on top: `isCurrent =
i === active; isPassed = !isCurrent && i < reached`. This is a second
  documented case (after the NA-34 triage-card width entry) of a plan
  resolving/simplifying an ambiguity in the raw design script — implement
  the plan's literal resolution, not the mock's original state machine,
  and don't try to reconcile the two.
- Reused three established patterns verbatim rather than re-deriving them:
  the `getHomeFaqs`/`faq.ts` try/catch-log-return-empty-sentinel shape for
  both new `why-sdlc.ts` readers (only the collection/global/field names
  differ); the `(frontend)/page.tsx` single-top-level-async-boundary +
  `Promise.all` pattern for `WhySdlcPage`; and `control-section.tsx`'s
  "co-locate static illustration/script data as typed consts inside the
  one component that renders them" pattern for `argument-rail.tsx`'s five
  mono illustrations (spec Open Question 2's suggested default).
- `getWhySdlcContent()`'s return type comes entirely from `payload.findGlobal({
slug: 'whySdlc', depth: 0 })`'s own generic inference (same as `find()`'s
  `GeneratedTypes` augmentation, NA-35 memory) — no manual `<WhySdlc>` type
  parameter needed on the call.
- `pnpm nx build marketing` (Turbopack, Next 16, no live DB) succeeds with
  `/why-sdlc` correctly listed as `ƒ` (dynamic) in the route summary once
  `export const dynamic = 'force-dynamic'` is set (same convention as the
  home page, per `docs/adr/0010-cms-force-dynamic-and-migration.md`) —
  confirms the build-time static-prerender trap doesn't apply here either,
  no live Postgres needed for this story's verification.
- `pnpm nx format:write --uncommitted` after a full build+lint+test pass
  only touched `apps/marketing/next-env.d.ts` (the `./.next/dev/types/...`
  vs `./.next/types/...` import-path churn documented in the NA-16
  Copilot-review-fix entry below) — discarded via `git checkout --` rather
  than committed, per that entry's guidance, leaving a fully clean tree
  across all 6 task commits.

**Patterns:**

- A scroll-progress `{ reached, active }` pair split across two independently-
  meaningful roles: `reached` is monotonic (`Math.max(prev.reached, next)`,
  never decreases, drives the CTA kicker's one-way "all gates passed" flip)
  while `active` is non-monotonic (tracks whichever section the user is
  currently viewing, drives the sticky pane's crossfade/caption and which
  single gate node pulses). Keeping both fields on one context object (one
  `ScrollProgressProvider` wrapping the rail, the server-rendered FAQ as
  `children`, and the CTA kicker) is what lets a gate-rail node and the CTA
  copy agree without prop-drilling across three sibling files.

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
  migrated Postgres schema at build time" constraint documented in
  `docs/adr/0010-cms-force-dynamic-and-migration.md` (see also
  `docs/adr/0009-cms-read-try-catch-fallback.md` for the fallback that
  constraint pairs with; that constraint is specific to pages that
  actually call Payload's Local API). Good fast way to get real
  `tsc`-equivalent type-checking signal for a story with no repo
  `typecheck` target — `next
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

## 2026-07-12 — Story NA-35 — home FAQ preview + Final CTA (first Home CMS fetch)

**Learnings:**

- This is the first Home section that actually reads from Payload (every
  prior Home section — NA-30 through NA-34 — was static). Established the
  pattern: keep the Payload fetch at the **page's own top-level async
  boundary** (`(frontend)/page.tsx` itself becomes `async function
HomePage()`), with a small `lib/faq.ts` data-access function
  (`getHomeFaqs()`) doing the actual `payload.find()` + try/catch fallback
  to `[]`. Every section below — `FaqPreview`, `FaqAccordion` — stays a
  plain synchronous server/client component receiving already-resolved
  props. This directly follows the NA-16 memory's "don't nest a second
  async Server Component inside another render for RTL" rule, applied for
  the first time in this story rather than just documented.
- `payload.find({ collection: 'faq', where: { showOnHome: { equals: true
} }, sort: 'homeOrder', limit: 5, depth: 0 })` is all AC1's "top-5 FAQ"
  needs — the seed data (`seed/data.ts`) already carries a dedicated
  `homeOrder`/`showOnHome`/`homeAnswer` triple per doc distinct from the
  full-FAQ-page fields (`whySdlcOrder`, plain `answer`), so no client-side
  slicing/sorting was needed.
- `@payloadcms/richtext-lexical/react`'s exported `RichText` component
  carries **no** `'use client'` directive — confirmed by reading its
  compiled `dist/.../Component/index.js` before assuming otherwise. It's
  safe to call directly inside a plain server component
  (`<RichText data={faq.answer} disableContainer />`), so converting each
  FAQ answer's Lexical JSON to JSX happens server-side; only the
  open/close toggle state (`useState` in `FaqAccordion`) ships to the
  client. `disableContainer` avoids its default `<div
className="payload-richtext">` wrapper; style the inner `<p>`/`<code>`
  via a Tailwind arbitrary descendant selector (`[&_p]:text-[17px]
[&_code]:text-[var(--terra-400)]`) on your own wrapper div instead.
- `@payloadcms/richtext-lexical` (and by extension its `/react` subpath)
  ships plain ESM with no CJS build — importing it un-mocked in a Jest
  spec throws `SyntaxError: Unexpected token 'export'` (Jest's default
  `transformIgnorePatterns` skips all of `node_modules`). Rather than
  touching the shared `jest.config.cts`'s `transformIgnorePatterns` (a
  repo-wide risk for one component), `jest.mock('@payloadcms/richtext-lexical/react',
() => ({ RichText: fakeThatExtractsPlainTextFromTheSameLexicalShape }))`
  in every spec that renders `FaqPreview` (directly, or transitively via
  `HomePage`) sidesteps it — the real converter is third-party/well-tested,
  not something this story needs to verify.
- Extending `CtaButton` (`packages/ui`) with a third `size="lg"` (48px
  height, matching the nightshift-design skill's own `Button` `lg` spec:
  `padding:'0 24px', height:48, fontSize:15`) for the Final CTA's star
  button followed the exact same `SIZE_CLASSES` record-extension pattern
  as the NA-34 entry below — one more size key, no `BASE_CLASSES`/variant
  changes needed, every existing call site unaffected.
- An accordion row whose default-open state is driven by a `useState`
  default (`openIndex = 0`) and whose max-height comes from a
  client-effect-measured `scrollHeight` has a real bug if you don't
  special-case the pre-effect render: the initially-open row would be
  clipped to `max-height: 0` (SSR output + first client render, before
  `useEffect` fires) even though `opacity: 1` — content invisible until
  hydration completes. Fix: track the measured height as `number | null`
  (not defaulting to `0`) and fall back to `max-height: 'none'` whenever
  `isOpen && measuredHeight === null` — `'none'` shows full content with
  no clipping on the SSR/pre-hydration render, then swaps to the real
  pixel value post-mount with no visible jump (both values fully reveal
  the same content). Caught this by reasoning through the render timeline
  before shipping, not from a failing test — jsdom's `render()` flushes
  effects synchronously via `act()`, so a naive RTL test wouldn't have
  caught the bug (the "before-effect" frame isn't observable there); the
  actual risk is the real browser's paint-before-first-effect frame.
- `payload.find`'s generic return type comes entirely from the
  `declare module 'payload' { interface GeneratedTypes extends Config {}
}` augmentation at the bottom of `payload-types.ts` — no manual
  `<Faq>` type parameter needed on the call itself; `docs` and
  `doc.homeAnswer`/`doc.answer` are already fully typed from
  `collection: 'faq'` alone.

**Patterns:**

- Mocking `getPayload` from `'payload'` without hitting the
  babel/SWC-jest-hoist TDZ trap (documented in the NA-16 memory for
  `mock`-prefixed closure vars): when the factory would otherwise need to
  reference an outer `const`, don't — `jest.mock('payload', () => ({
getPayload: jest.fn() }))` with an **inline, self-contained** factory,
  then retrieve the same mock function back via `import { getPayload }
from 'payload'; const mockGetPayload = getPayload as jest.Mock;` in the
  test body. Configure its resolved value in `beforeEach`. Zero TDZ risk
  since the factory never closes over anything outside itself.
- A design mock's raw `faqOpen: 0` initial state (one entry open by
  default) is worth preserving literally rather than "improving" to
  all-closed — matches the handoff's own interaction spec and gives the
  animated max-height something to visibly demonstrate without user
  interaction.

## 2026-07-12 — Motion migration of home/ hand-rolled CSS animations (no ticket, dispatched off `refactor/motion-gsap-animations`)

**Learnings:**

- Grepping `animate-\[ns-\|animation:\|motion-safe:animate` across
  `home/*.tsx` first, before opening every file, immediately narrowed a
  12-file dispatch down to the 3 that actually had hand-rolled CSS
  animation to migrate: `phrase-marquee.tsx` (`ns-marquee`
  loop), `team-preview.tsx` (`ns-twinkle` star dot), and
  `control-section.tsx` (`ns-risein`/`ns-slam`/`ns-gatepulse`/`ns-twinkle`,
  6 call sites). The other 9 files (hero, proof-bar, problem-section,
  how-it-works, day-night-workflow, why-different, faq-preview,
  faq-accordion, final-cta) have zero animation of their own — don't
  touch them just because they're in the dispatch's file list; plain CSS
  `transition: 'x .3s'` property changes (hover dim, hairline color
  fades in control-section/team-preview) are NOT in scope for a
  `@keyframes`→Motion migration and were left alone.
- `faq-accordion.tsx` (home/) has no animation code at all — the actual
  expand/collapse max-height/opacity transition lives in the shared
  `../faq/faq-row.tsx` (extracted in NA-38 so home preview + the full
  `/faq` page accordion can't drift), which is **outside** `home/` and
  therefore outside a `home/`-scoped dispatch's ownership even though the
  task brief describes the accordion as if the animation were local to
  `faq-accordion.tsx`. Read the actual delegation before assuming the
  brief's file-purpose description is accurate — don't duplicate
  shared-component logic into a wrapper just to satisfy a brief's framing.
- `jest.setup.dom.js` (repo root) already polyfills `matchMedia` (always
  `matches:false` unless a test overrides it), `IntersectionObserver`,
  `ResizeObserver`, `scrollTo` globally for every Nx project — confirmed
  by reading it directly rather than assuming. Existing Motion specs
  (`terminal.spec.tsx`, `count-up.spec.tsx`) never advance real animation
  frames or depend on `requestAnimationFrame` actually ticking in jsdom;
  they only assert the pre-animation-complete state (initial
  deterministic frame, or the reduced-motion jump-to-final state).
  Followed the same testing shape for the home migrations — never
  asserted mid-animation values, only initial/gated state.
- Motion's `animate` prop computes styles synchronously even during SSR
  (no flash-of-unstyled-content), which means a **direct**
  `prefersReducedMotion()` call in a component's render body (not inside
  `useEffect`) would produce different JSX between the server render
  (`window` undefined → always `false`) and the client's first hydration
  render (`window` defined → real user preference) — a hydration
  mismatch. Every reduced-motion gate in this migration follows the
  Terminal/CountUp precedent instead: `useState(false)` +
  `useEffect(() => setReducedMotion(prefersReducedMotion()), [])`, so the
  deterministic first frame always matches SSR, and the real preference
  only applies post-mount (one JS tick of unavoidable non-reduced motion
  on a true reduced-motion user's very first paint — accepted tradeoff,
  already baked into this codebase's Terminal/CountUp precedent, not
  something this migration introduced).

**Pitfalls:**

- `team-preview.spec.tsx` had one test that asserted a Tailwind class
  marker (`row.querySelector('[class*="motion-safe:animate"]')`) as its
  only way to verify the twinkle animation was reduced-motion-gated —
  once the dot moves to Motion's JS `animate` prop there's no className
  to grep for anymore. Fixed by adding an explicit `data-testid="team-dot"`
  - `data-twinkle="on"|"off"` attribute pair purely for test observability
    (harmless, `aria-hidden` decorative element) rather than trying to
    infer gating from Motion's internal style application — cleaner and
    actually verifies the _behavioral_ gate (mocks `matchMedia` true/false,
    asserts the attribute flips) instead of a static-markup proxy.
- `control-section.tsx`'s `CtrlGate.anim: string` field (`'ns-gatepulse …'
| 'none'`) baked the CSS animation shorthand directly into the derived
  view-model returned by `buildCtrlGates`. Migrating cleanly required
  changing that field to `awaiting: boolean` and letting the _rendering_
  component (`GateStrip`) decide the Motion `animate`/`transition` props
  from it — don't carry a target-technology-specific string (a CSS
  animation shorthand) through a pure derivation function when the
  renderer can trivially compute the same branch from a boolean.

**Patterns:**

- Continuous decorative loop (`ns-twinkle`, `ns-marquee`, `ns-gatepulse`)
  → a shared constant `{ opacity: [...], filter: [...] }` (or `x`/`scale`)
  object passed to `animate`, paired with a `transition={{ duration,
ease, repeat: Infinity }}`, both swapped to `undefined` under
  `reducedMotion` (Motion treats `animate={undefined}` as "render the
  current/initial state, do nothing" — simplest possible reduced-motion
  off-switch for a loop, no separate `if` branch needed at the JSX call
  site itself).
- One-shot entrance (`ns-risein`, `ns-slam`) → `initial={reducedMotion ?
false : {...}}` + `animate={{...}}` + `transition={{ duration:
reducedMotion ? 0 : N, ease: EASE_OUT }}`. `initial={false}` is Motion's
  own idiom for "skip the enter animation, render directly in the
  `animate` end-state" — cleaner than conditionally omitting the
  `initial` prop. For a 3-keyframe entrance (`ns-slam`: overshoot then
  settle), keyframe arrays (`y: [-18, 2, 0]`, `scale: [1.05, 1, 1]`) plus
  `transition.times: [0, 0.6, 1]` reproduce the CSS `@keyframes`
  percentage stops directly — no need for a multi-stage `animate()`
  sequence call.
- Repeated multi-call-site entrance props (`ns-risein` used 3x across
  `control-section.tsx`'s race terminals) — factor into a small
  prop-spread helper (`riseInProps(reducedMotion, durationS = 0.4)`
  returning `{ initial, animate, transition }`) and spread it
  (`{...riseInProps(reducedMotion)}`) rather than repeating the same
  three props at every call site.
- `--ease-out: cubic-bezier(.22,1,.36,1)` (nightshift-design token) is
  the exact numeric equivalent of the `motion-dev-animations` skill's own
  "Pattern 1" easing curve (`[0.22, 1, 0.36, 1]`) — no translation needed
  between the design system's token and Motion's array-tuple easing
  format when porting a design-authored `var(--ease-out)` CSS animation.
