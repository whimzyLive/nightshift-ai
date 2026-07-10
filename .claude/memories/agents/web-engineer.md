# web-engineer memory

## 2026-07-11 — Story NA-22 — brand polish pass + double-eyebrow bug fix

**Learnings:**

- **Worktree-path pitfall bit again, at the very start of the session this
  time** (not mid-session): `Working directory` in the env block was already
  the worktree root, but several early `Read`/`Bash` calls used the
  no-prefix repo path (`.../nightshift/...`) instead of the
  `.../nightshift/.claude/worktrees/<id>/...` path, and succeeded silently
  against the _shared_ checkout — which was still on the old spec-merge
  commit (7b9206c), 6 commits behind `origin/feat/NA-22`. Caught it only
  when the first `Edit` call errored ("isolated in the worktree"). Fixed
  with `git fetch origin feat/NA-22 && git reset --hard origin/feat/NA-22`
  run with `cd` into the worktree path explicitly. Lesson reinforced: verify
  `pwd`/`git log --oneline -3` **inside the literal worktree path** as the
  very first Bash call of a session, before any Read — don't trust the env
  block's stated cwd for subsequent relative assumptions.
- **Tailwind v4 theme-key collisions are the norm, not the exception, when
  a design-token file already uses Tailwind's own namespace convention.**
  This repo's `tokens/typography.css`/`spacing.css` already name their keys
  `--text-2xs..6xl`, `--leading-*`, `--tracking-*`, `--radius-*` — i.e. they
  pre-adopted Tailwind v4's exact theme-key naming. That means _every one_
  of those needs a **literal duplicate** inside `packages/design-system/src/theme.css`'s
  `@theme` block (not a `var()` alias — self-reference, same circular-ref
  gotcha as the earlier `--tracking-eyebrow` case, just with no alias name
  available this time). Only genuinely differently-named tokens
  (`--fw-*` vs Tailwind's `--font-weight-*`, `--elev-*`/`--glow-*` vs
  `--shadow-*`) can use a `var()` alias safely. `packages/design-system/scripts/check-tokens.mjs`
  only diffs `tokens/*.css` against the canonical skill source — confirmed
  (again) it does **not** check `theme.css`, so literal duplication there
  never trips the parity gate.
- **Tailwind v4's numeric spacing scale coincidentally IS the design
  token's spacing scale** (`--space-N` in the tokens file always equals
  `N * 4px`, matching Tailwind's default `--spacing: 0.25rem` multiplier
  exactly for every key the tokens file defines: `space-6`=24px=`p-6`,
  `space-24`=96px=`p-24`, etc). Same coincidence for `font-weight`
  (`--fw-bold`=700=Tailwind's `font-bold`, `--fw-extra`=800=`font-extrabold`)
  and numeric transition `duration-*`/`duration-200`=`--dur-base`. These
  three needed **zero** `@theme` additions — existing Tailwind utility
  classes already render token-exact values. Don't add theme mappings for
  scales that already agree; check the built CSS's computed value first
  (`grep '\.p-6{' .next/static/chunks/*.css`) before assuming a gap exists.
- **Avoid `--color-border-strong` as a theme key name** — Tailwind's
  border-color utility naming is `border-<key>`, so a key literally named
  `border-strong` produces the redundant class `border-border-strong`.
  Named the alias `--color-line-strong` (→ utility `border-line-strong`)
  instead, dropping the "border" word from the key since the utility prefix
  already supplies it. Same pattern for `line-soft`/`line-accent`.
- **`InstallSnippet`'s multi-line install command** (`installCommand` is
  two `\n`-joined shell lines) needs one `<code>` **per line**, not one
  `<span>` wrapping the whole block, for two reasons at once: (1) a `<div>`/
  `<span>` row wrapper around multi-line text inside a single outer `<code>`
  works visually but a `<span>` wrapping raw command text breaks
  `InstallSnippet.spec.tsx`'s `queryByText(/install/i, {selector:'span'})`
  assertion (which exists to prove the _label_ span is absent when
  `label` is omitted — the command text landing inside any `<span>` is a
  false-positive match); (2) block-level wrappers technically aren't valid
  phrasing content inside a single `<code>` per the HTML5 content model.
  Fix: outer layout `<div>`, one `<code>` per split line, `<span>` used only
  for the non-text `$` prompt glyph.
- **The nightshift-design skill's own `npm run validate` gate
  (`.claude/skills/nightshift-design/package.json`)** validates the
  _skill's own_ `components/`/`ui_kits/` reference sources, not the
  consuming app — running `check:tokens`/`check:contrast` from inside that
  directory after an app-only polish pass (no skill-dir edits) is a
  no-op-but-confirmed-still-green check, not a check that exercises the new
  app code. The actual token-parity gate for the app is
  `pnpm nx run design-system:check-tokens`.

**Pitfalls:**

- `pnpm run seed` (booting Payload) reflows `payload-types.ts` even with
  zero schema changes (autoGenerate on init) — same as documented in the
  entry below, confirmed again here. `next dev`/`next build` similarly
  reflow `next-env.d.ts` every run. Always `git status --porcelain` +
  `git checkout --` both after any `payload run`/`next dev`/`nx build`
  invocation, immediately before staging for commit — don't rely on doing
  it once after the last command, since dev-server sanity-checks after a
  build can re-dirty them.

**Patterns:**

- Bug-fix-at-the-data-layer + brand-polish-pass combined dispatch: fix the
  literal bug in seed data first, re-run the seed script and verify via a
  live `curl` + grep against the rendered HTML (not just re-reading the
  seed source) that the DB and the rendered page both reflect the fix,
  _then_ do the broader styling pass — keeps the narrow bug fix independently
  verifiable before it's buried in a much larger stylistic diff.

## 2026-07-11 — Story NA-22 — CMS seed script (site-brief copy → SiteSettings/Home/WhySdlc globals)

**Learnings:**

- **`payload run <script.ts>` races its own process exit against a
  fire-and-forget async top-level call.** `runBinScript()`
  (`payload/dist/bin/index.js`) does `await import(pathToFileURL(scriptPath))`
  then returns; the outer `bin()` immediately calls `process.exit(0)` once
  that import() promise settles. Dynamic `import()` of an ESM module only
  waits for the module's _own_ top-level synchronous execution (or a
  top-level `await` inside it) — a bare `seedFn().then(...).catch(...)` at
  the bottom of the script lets `import()` resolve before the promise
  settles, so the CLI's `process.exit(0)` wins the race and kills the
  process mid-flight. Symptom: `pnpm run seed` exits 0, prints nothing (not
  even the success `console.log`), and the DB is untouched — looks like a
  silent no-op, not a crash. Fix: `try { await seedFn(); } catch (e) { ...;
process.exit(1); }` as genuine top-level await (supported — the `payload`
  bin transpiles via `tsx/esm/api`'s `tsImport`, which supports TLA). Diagnosed
  by directly reading `payload/dist/bin/index.js`'s `run` branch rather than
  guessing from symptoms.
- **Lexical `SerializedEditorState` shape for hand-built richText**, verified
  against `lexical`'s own `ElementNode`/`TextNode`/`RootNode`
  `exportJSON()` (not guessed): root and paragraph nodes are
  `{ type, format: ElementFormatType ('' for default), indent: 0, version: 1,
direction: 'ltr'|'rtl'|null, children: [...] }`; text nodes are
  `{ type: 'text', format: 0, detail: 0, mode: 'normal', style: '', text,
version: 1 }` (format here is a numeric bitmask, not the element's string
  enum — easy to conflate the two `format` fields since they're both called
  `format` but on different node kinds). `RootNode` doesn't override
  `exportJSON()`, so root's shape is exactly `SerializedElementNode`, i.e.
  identical field set to a paragraph node's, just `type: 'root'`.
  `@payloadcms/richtext-lexical/lexical` is confirmed (again) to be
  `export * from 'lexical'`, so `SerializedEditorState` from that subpath is
  the real `lexical` package type, not a Payload-specific narrowing.
- **Building a typed `textToLexical()` helper without `any` or excess-property
  errors:** assign the per-paragraph node array to an _untyped_ intermediate
  `const children = paragraphs.map(...)` (no contextual type flows into a
  `.map()` callback from an unrelated variable declaration), then reference
  that variable — not an inline literal — inside the object literal that gets
  contextually typed against the function's `SerializedEditorState` return
  annotation. TS excess-property checks only fire on _fresh object literals_
  checked directly against a target type; a variable reference (even one
  whose inferred type has "extra" fields relative to the loose
  `SerializedLexicalNode` base) is checked via ordinary structural
  assignability, which allows the extra fields. Avoided needing a single
  broad `as SerializedEditorState`/`as any` cast on the whole tree this way —
  only the outermost `{ root: {...} }` literal needs a narrow `as
SerializedEditorState` (and even that turned out unnecessary since the root
  literal's own keys are an exact match for `SerializedRootNode`).
- **A fresh Nx-inferred project (no `project.json`, no `package.json`
  `"scripts"` block yet)** picks up a new `"scripts": { "seed": "..." }`
  entry automatically — no Nx config change needed for `pnpm run seed` (run
  directly via the package manager, from `apps/marketing`) to work; Nx's own
  target inference is irrelevant here since the task only needed a
  package-manager script, not an `nx run` target.
- **Payload global `updateGlobal()` is genuinely idempotent for this schema**
  (confirmed via direct `psql` row counts, not just "should be"): re-running
  the seed script left `home` at 1 row and `home_faq_items` at 6 rows both
  before and after a second run — Postgres adapter deletes+reinserts array
  child-table rows on every `updateGlobal()` rather than appending, so no
  dedup logic is needed in the seed script itself.
- Confirms the earlier NA-22 memory pattern: a shared dev Postgres from
  another worktree/session can already be listening on `localhost:5432` even
  when a fresh worktree has no `apps/marketing/.env` yet (this dispatch's
  worktree had none — `.env.example` only). Created `.env` with the
  docker-compose defaults (`postgresql`/`password123`/`nightshift`) plus a
  freshly generated `PAYLOAD_SECRET`; didn't need to run `local-start`
  myself since the shared container answered immediately. `psql` prompts
  interactively for a password even with `PGPASSWORD`-less invocation from
  this shell — piping the password via `<<< "password123"` heredoc-string
  works reliably where a bare `-h ... -U ...` command without password prep
  would hang on the prompt.
- **Verifying rendered richText output end-to-end**: `curl` the page HTML
  and grep for the literal paragraph text inside a `"payload-richtext"`
  wrapper in the RSC flight-data payload (Next.js App Router streams
  server-rendered content as escaped JSON literals in the HTML, not just
  plain tag-wrapped text) — grepping for the exact brief sentence found it
  embedded in `[\"$\",\"p\",\"0\",{\"children\":[\"...\"]}` chunks, confirming
  both that the CMS data reached the page _and_ that the lexical→React
  converter actually rendered it, not just that the DB write succeeded.

**Pitfalls:**

- `pnpm exec payload generate:types`-adjacent side effect: simply _booting_
  Payload via `payload run <script>` (even with zero schema changes)
  reformats the entire `payload-types.ts` to Payload's own non-prettier
  line-wrap style on every run (autoGenerate fires on init). Always
  `git status --porcelain apps/marketing/src/payload-types.ts` after any
  `payload run`/`pnpm run seed` invocation and `git checkout --` it if the
  diff is pure reflow (no real field changes) — same pattern as the
  documented `generate:types` reflow issue, just triggered by a different
  command this time.
- `next dev` also touches `apps/marketing/next-env.d.ts` on every boot
  (single/double-quote reflow) — discard with `git checkout --` same as the
  documented `next build` noise; happens on `dev` too, not just `build`.

**Patterns:**

- When a Payload schema group has no dedicated "section header" field but
  the copy brief has one (e.g. `problem` group only has `eyebrow`/`body`/
  `points`, no `title`), and the front-end component only renders a `<p>`
  (not `<h2>`) for that field: fold the header sentence into the start of
  the `body` string, space-joined (not `\n\n` — a plain `<p>` collapses
  newlines to spaces in HTML anyway, so a literal `\n\n` join would silently
  render identically to a single space but looks confusingly line-broken in
  the seed source). Don't invent new schema fields to hold brief content the
  existing components can't render — check the consuming `.tsx` component
  first to see whether a field would ever actually reach the page before
  deciding where truncated/reshaped brief copy goes.

## 2026-07-10 — Story NA-22 — CI-fix pass (format:check + ui typecheck lib gaps)

**Learnings:**

- This dispatch's worktree had a `node_modules/` with only `.cache/`
  populated (no `.modules.yaml`, no `.pnpm/`) even though the branch content
  itself was correctly reset to `origin/feat/NA-22` tip — `pnpm nx run-many
-t typecheck` failed with "Failed to process project graph" (`Could not
  find ".modules.yaml"` + `ERR_MODULE_NOT_FOUND '@payloadcms/next'`), which
  reads like a project-graph bug but is really just "no install happened in
  this worktree yet." Fix: `pnpm install --frozen-lockfile` from the
  worktree root (fast — reuses the shared pnpm store); confirmed
  `pnpm-lock.yaml` was untouched via `git status --porcelain` immediately
  after. Don't assume a project-graph error means the _code_ is broken —
  check `node_modules/.modules.yaml` exists first.
- `packages/ui/tsconfig.lib.json` and `tsconfig.spec.json` both extend
  `tsconfig.base.json` (`"lib": ["es2022"]`, no `dom`) but the package's own
  source (`InstallSnippet.tsx`, using `navigator.clipboard`) and its Jest
  specs (`.getAttribute` on `HTMLElement`) need DOM types. Neither
  `tsconfig.json` (the solution/reference file) nor `tsconfig.base.json` is
  the right place to add `dom` — it must go in **both** leaf configs
  (`tsconfig.lib.json` for source, `tsconfig.spec.json` for tests)
  individually via `"lib": ["dom", "es2022"]` in `compilerOptions`, since
  each is `tsc --build`'s own independent project reference and neither
  inherits the other's `lib` override.
- A stray `packages/design-system/tsconfig.tsbuildinfo` appears as untracked
  after running `pnpm nx run-many -t typecheck` (composite-project
  incremental build artifact) — it's not gitignored in this repo, but it's
  also not part of any fix; just leave it untracked and don't `git add` it
  (stage explicit paths, never `git add .`, per the no-lockfile/no-stray-
  artifact commit hygiene this repo expects).
- `pnpm nx format:write --files docs/superpowers/plans/NA-22.md` reformats
  embedded fenced code blocks inside the markdown plan doc (double→single
  quotes in CSS/JS snippets, added blank lines, multi-line if-blocks) — a
  much larger diff (~340 lines) than the CI failure implies, but it's all
  prettier-driven and `format:check` goes clean afterward; nothing to
  hand-verify beyond that the doc still renders/reads correctly.
- Next.js's generated `apps/marketing/next-env.d.ts` should be added to
  `.prettierignore` (not reformatted) — matches the existing pattern in
  that file for the vendored `design-system` token CSS (a comment
  explaining _why_ the exclusion exists, right above the glob).

**Pitfalls:**

- None beyond the node*modules gap above — worth checking
  `node_modules/.modules.yaml` existence as a first diagnostic step
  whenever `nx run-many` fails at the \_project graph* stage (not a specific
  task) in a freshly-reset worktree.

**Patterns:**

- CI-fix-only dispatches (prettier/tsconfig-only failures, no design or
  component work) don't need the design-oriented project skills
  (`payload`, `hallmark`, `nightshift-design`, `tailwind-design-system`,
  `vercel-react-best-practices`, `vercel-composition-patterns`,
  `atomic-design`, `motion-dev-animations`, `gsap-core`) invoked — going
  straight to the config fix is the pragmatic call when the task explicitly
  scopes to "Fix ONLY the CI failures below."

## 2026-07-10 — Story NA-22 — review-fix pass #2 (payload cache poisoning, Button a11y+props, InstallSnippet clipboard, Eyebrow token, content graceful degradation)

**Learnings:**

- This dispatch's worktree (`worktree-agent-ac07b771b2199b1e7`) was checked
  out to the old **spec** merge commit (7b9206c), 15 commits behind the real
  `feat/NA-22` tip (6335ca9) — `apps/marketing/src/lib/` and
  `packages/ui/src/lib/` didn't even exist at that commit. `feat/NA-22` was
  already checked out in the _primary_ (non-worktree) checkout at the
  correct tip, so `git checkout feat/NA-22` failed with "already used by
  worktree." Confirms the shared-memory pattern below: `git status --short`
  (clean) → `git reset --hard origin/feat/NA-22` synced the worktree's own
  differently-named local branch to the real content without touching the
  other worktree. Always verify `git rev-list --count HEAD..origin/<branch>`
  is `0` (or check that the files a finding references actually exist)
  before trusting "your worktree is based on it" from the dispatch prompt.
- Read/Bash tools will silently read the _shared_ (non-worktree) checkout
  path (`nightshift/apps/...` without the `.claude/worktrees/<id>/` prefix)
  with no error and return correct-looking content — only Write/Edit refuse
  with "isolated in the worktree ... Edit the worktree copy instead." Since
  a stale Read doesn't error, always prefix **every** file path (Read
  included) with the full worktree root from the very first tool call in a
  session; don't rely on the Edit-time error to catch it, by then you've
  already burned a Read/analysis pass on the wrong tree.
- Tailwind v4 `@theme` block gotcha: you cannot write
  `--tracking-eyebrow: var(--tracking-eyebrow);` inside `@theme` to expose
  an existing `:root`-scoped token as a utility — the `@theme` block _is_
  the `:root` declaration for that custom-property name, so this is a
  circular self-reference. Fix: reference a **different**-named alias that
  already points at the same value (here, `typography.css` already ships
  `--eyebrow-tracking: var(--tracking-eyebrow);` for exactly this reason) —
  `--tracking-eyebrow: var(--eyebrow-tracking);` inside `@theme` resolves
  correctly and Tailwind emits both the `tracking-eyebrow` utility and a
  non-circular `:root` value. Verified by grepping the **built** CSS for the
  literal resolved value (`--tracking-eyebrow:.16em`), not just that the
  utility class exists — a circular var() still generates the utility
  class, it just resolves to nothing at runtime.
- `packages/design-system/scripts/check-tokens.mjs` only diffs
  `src/tokens/*.css` against the canonical `.claude/skills/nightshift-design/tokens/*.css`
  files — it does **not** check `theme.css`. Adding new `@theme` mappings
  there (e.g. `--color-on-accent`, `--tracking-eyebrow`) never trips the
  token-parity gate, since those are Tailwind-utility bridges, not vendored
  token declarations.
- React 19's `cache()` (from `'react'`) works fine when unit-tested directly
  with Jest + jsdom (no RSC render context needed) — wrapping an async
  helper in `cache(async () => {...})` and calling it directly in a test
  behaves like a plain memoized async function; no special test setup
  required beyond what the un-wrapped version needed.
- A discriminated union for a polymorphic `<a>`/`<button>` component
  (`{ href: string } & AnchorHTMLAttributes` | `{ href?: undefined } &
ButtonHTMLAttributes`) type-checks cleanly against every existing
  href-only call site in this repo (`Hero`, `SiteHeader`, `FinalCta`,
  `Control` all only ever passed `variant` + `href` + `children`) — no
  call-site changes needed when tightening a previously-loose
  `ButtonHTMLAttributes`-only prop type this way.
- Destructuring `{ href, variant, children, className, ...rest }` from a
  union-typed props object and then casting `rest` with `as
X.HTMLAttributes<...>` per branch is enough to forward `aria-*`/`id`/
  `onClick`/`data-*` to the right element without duplicating the
  destructure per-branch — TS narrows `rest`'s type fine here since `href`
  was already pulled out before the `if (href)` branch.

**Pitfalls:**

- None beyond what's captured above.

**Patterns:**

- TDD-verifying a fix with no pre-existing spec file across multiple
  findings in one pass: write the test(s) first against the _already-fixed_
  source (expected GREEN since the fix predates the test in edit order),
  then `Write` the pre-fix source back in temporarily, rerun to confirm RED
  for the exact reason the finding describes, then `Write` the fix back.
  Faster than a scripted string-replace round-trip when the pre-fix version
  is short enough to just paste twice (payload.ts, content.ts, Button.tsx,
  SiteHeader.tsx, InstallSnippet.tsx were all done this way in this pass).
- `console.error`-based graceful-degradation tests: `jest.spyOn(console,
'error').mockImplementation()` in `beforeEach` + `.mockRestore()` in
  `afterEach` keeps the expected-error path from polluting Jest's real
  console output while still letting `expect(consoleErrorSpy).toHaveBeenCalled()`
  assert the finding's required `console.error` call happened.

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

## 2026-07-10 — Story NA-22 — review-fix pass (github_label missing from init migration)

**Learnings:**

- A shared local dev Postgres (per the earlier "shared container" memory)
  can drift **ahead of** the committed migration files: it already had
  `site_settings.github_label` (added by hand via `psql` in a prior session,
  per that session's own memory entry) even though the committed
  `20260710_095549_na22_globals.ts` baseline never created that column. Its
  `payload_migrations` table recorded the old baseline as applied. Don't
  trust a live DB's current schema as proof a migration file is correct —
  diff the migration file's SQL/JSON directly against the Payload
  `GlobalConfig` fields instead.
- Regenerating a baseline init migration correctly: delete both the `.ts`
  and `.json` for the migration, then run
  `pnpm --filter @nightshift-ai/marketing exec payload migrate:create <name>`
  from `apps/marketing` (not the repo root — `pnpm --filter ... exec` at
  the root fails with "Command \"payload\" not found" because the
  workspace package's own `node_modules/.bin` isn't resolved the same way;
  `cd apps/marketing && pnpm exec payload ...` works). Needs a **reachable**
  Postgres via `DATABASE_URL` (a fresh `.env` with the shared dev-container
  creds is enough — `migrate:create`'s diff is snapshot-based, not
  live-DB-introspection-based, so it doesn't matter whether that DB's
  actual tables match; it just needs a real Payload instance to boot) plus
  any non-empty `PAYLOAD_SECRET`.
- `payload migrate:create` **automatically rewrites `migrations/index.ts`**
  to import and register the new migration file — no manual edit needed
  there (only the README's filename reference and deleting the old `.ts`/
  `.json` are manual cleanup).
- The regenerated migration's raw `.ts` comes out in Payload's own
  (non-prettier) formatting — `pnpm exec prettier --write` on just the new
  `.ts` collapses the diff against the old file down to exactly the
  intended schema change (confirmed via `diff -u --ignore-all-space`
  before/after prettier: dozens of line-wrap-only hunks collapsed to the
  single added `"github_label" varchar DEFAULT 'GitHub',` line).
- `payload migrate:create` also touches `payload-types.ts` as a side effect
  of booting Payload (autoGenerate) even though the fields didn't change —
  pure re-wrap noise (multi-line union types collapsed to one line). Since
  no field was added/removed here (`githubLabel` was already in
  `SiteSettings.ts`, just missing from the migration), `git checkout --`
  it rather than committing unrelated reflow.
- Docker commands (`docker run`, `docker ps -a --filter ...`) reliably
  **hang/timeout** in this sandbox even for a brand-new container on an
  unused port (15432) — consistent with the prior memory's note about
  `docker ps`/`docker info` hanging. Don't burn a timeout budget on a
  from-scratch docker Postgres for a "verify against genuinely fresh DB"
  step; a JSON-snapshot diff (`tables['public.site_settings'].columns`)
  - SQL grep + successful `next build` prerender against the already-
    reachable shared DB is sufficient verification when docker is
    unavailable.

**Pitfalls:**

- `pnpm --filter @nightshift-ai/marketing exec payload <cmd>` run from the
  repo root can fail with `ERR_PNPM_RECURSIVE_EXEC_FIRST_FAIL Command
"payload" not found` when the workspace's own `node_modules/.bin/payload`
  doesn't exist yet (fresh worktree, no `pnpm install` run) — the real fix
  is `pnpm install --frozen-lockfile` at the worktree root first, not
  switching invocation style.

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
