# platform-engineer memory

## 2026-07-19 — Story NA-63 (Phase 2) — custom PluginJsonVersionActions module

**Learnings:**

- The public barrel `nx/release` maps (via nx@23.0.1's package.json `exports`) to
  `dist/release/index.d.ts`/`.js`, which re-exports `VersionActions` from the internal
  `src/command-line/release/version/version-actions` module — confirmed this resolves both at
  typecheck time and at runtime (loaded the compiled `.ts` file with `ts-node -e` and checked
  `Object.getPrototypeOf(Cls).name === 'VersionActions'`). The deep path `nx/release/version-actions`
  has a `./release/*` wildcard entry in `exports` but no `dist/release/version-actions.d.ts`/`.js`
  actually exists on disk — the wildcard matches syntactically but the file 404s, hence
  `MODULE_NOT_FOUND` at runtime (spec's warning verified, not just trusted).
- The base `VersionActions.init(tree)` (called by Nx before any of the abstract methods run)
  already resolves `manifestRootsToUpdate` + `validManifestFilenames` into `this.manifestsToUpdate`
  (`{ manifestPath, preserveLocalDependencyProtocols }[]`), interpolating `{projectRoot}` for us.
  Implementing methods should consume `this.manifestsToUpdate[0].manifestPath` rather than
  re-deriving the join by hand from `projectGraphNode.data.root` — simpler and can't drift from
  whatever `nx.json`'s `manifestRootsToUpdate` actually says.
- `Tree`/`ProjectGraph` types aren't exported from any `nx` package.json `exports` entry by name,
  but nx's `exports` map has a `./src/*` wildcard → `dist/src/*.d.ts` that genuinely has a compiled
  `.d.ts` on disk (unlike the `version-actions` deep-path trap above) — `import type { Tree } from
'nx/src/generators/tree'` resolves cleanly under `moduleResolution: "bundler"`. Since it's a
  type-only import it's erased at runtime, so no `MODULE_NOT_FOUND` risk even though it's a "deep"
  path.
- Overriding/implementing an abstract base-class method under `noImplicitOverride` (this repo's
  tsconfig.base.json setting) requires the `override` keyword even on members that only _implement_
  an abstract member (not just concrete-method overrides) — omitting it is a tsc error.
- A subclass method implementing an abstract member with more parameters (e.g.
  `readCurrentVersionOfDependency(tree, projectGraph, name)`) can be declared with **zero**
  parameters in the override — TS structural typing allows fewer declared params — which avoided
  needing the `ProjectGraph` type import at all for the three members that ignore their inputs.
- Preserving `plugin.json` key order/formatting on write: a JSON.parse→stringify round-trip risks
  reordering/reformatting; instead did a line-anchored regex replace
  (`/^(\s*"version"\s*:\s*)"[^"]*"/m`) that touches only the `"version"` value and leaves every
  other byte (indentation, key order, trailing newline) untouched.

**Pitfalls:**

- `pnpm exec tsc ...` in this repo is silently rewritten by the user's global `rtk` proxy hook —
  it printed `TypeScript: No errors found` but still exited `1`, which would have read as a false
  failure. Calling `./node_modules/.bin/tsc` directly bypassed the hook and gave a trustworthy
  `EXIT: 0`/no-output result. When a wrapped tool's exit code contradicts its own success message,
  re-run via the raw binary path before trusting the exit code.
- No Nx project (`project.json`) exists at the repo root and no `nx typecheck` target covers
  `tools/` — there's nothing to `pnpm nx typecheck source`. Verified instead with a manual `tsc
--noEmit` invocation replicating `tsconfig.base.json`'s compilerOptions by flag, plus a `ts-node -e`
  smoke-load to prove the runtime import (not just the type) resolves.

**Patterns:**

- `bash tools/portability-lint.sh` only scans `plugins/**` (confirmed again, per the NA-3 memory
  entry) — a green run is expected and uninformative for anything added under `tools/`; it's a
  required gate per the plan, but not evidence the new file itself is clean of anything beyond
  what the plan explicitly checked for (typecheck + no dependency changes).

## 2026-07-19 — Story NA-63 review fix — updateProjectVersion fails loud instead of failing open

**Learnings:**

- Original code did `if (!contents || !VERSION_FIELD_PATTERN.test(contents)) continue;` — under
  `git-tag`/`conventional-commits` resolvers `nx release` still tags + writes CHANGELOG.md even
  when the version-bump write to `plugin.json` was silently skipped, producing permanent,
  undetected tag↔manifest drift. Fixed by throwing instead of `continue`-ing on every failure path
  (unreadable manifest, zero matches, >1 match) — a manifest that can't record the bump must abort
  the whole release, not be silently skipped.
- Closed the "first-match-wins on a future nested `version` key" risk in the same pass: switched
  from `.test()` (which only proves ≥1 match exists) to `new RegExp(VERSION_FIELD_PATTERN.source,
'gm').match(contents)` to _count_ matches — exactly 1 is required; 0 throws "no top-level
  version field", >1 throws "ambiguous version fields (<n>)" naming the manifest path in both.
  Kept the original anchored line-based `VERSION_FIELD_PATTERN` (`^(\s*"version"\s*:\s*)"[^"]*"`,
  `m` flag) and the regex-replace write unchanged — this is a fail-fast guard in front of the
  existing formatting-preserving write, not a rewrite of the write strategy itself (JSON.parse/
  stringify was explicitly out of scope, would lose key order/formatting).
- Re-ran `./node_modules/.bin/nx release --dry-run --first-release` after the fix to prove the
  happy path is unaffected: both real plugins (`sdlc`→v1.0.0, `gtm`→v0.6.0) still bump
  `plugin.json`, changelogs/tags preview normally, `git status --porcelain` shows zero mutation —
  confirms the new throws only fire on the pathological 0-match/>1-match cases, never on the
  existing well-formed manifests.

**Pitfalls:**

- Same `rtk` proxy risk as the original NA-63 Phase-2 dispatch (see next entry below) — reused the
  raw `./node_modules/.bin/tsc --noEmit <flags-from-tsconfig.base.json>` invocation rather than
  `pnpm exec tsc` for a trustworthy exit code.

## 2026-07-18 — Story NA-62 (Phase B) — wire check-plugin-docs-format.sh into ci.yml

**Learnings:**

- Same shape as NA-25's guard wiring, confirmed again: `.github/workflows/ci.yml` still isn't a
  row in project-context's workspace→agent table, but the dispatch (backed by the spec's explicit
  Ownership-split table) named it platform-engineer's — one `- run: bash
plugins/sdlc/scripts/<guard>.sh` line appended after the last existing guard step, content of
  the guard script itself strictly off-limits (ai-enablement-engineer's artifact, authored in
  Phase A on the same shared branch). Two-phase single-PR stories with this owner split (script +
  sweep in one agent's phase, one-line `ci.yml` invocation in the other's) are a repeatable
  pattern now, not a one-off.
- This dispatch explicitly overrode the handoff protocol's default "commit only, PE pushes" —
  instructed to push `feat/NA-62` directly and confirm origin==local, with no PR/session-complete
  (a plan-writing-only continuation dispatch, not a full domain-agent phase handoff). Read the
  dispatch prompt's explicit push/no-push instruction before defaulting to the shared protocol.

**Patterns:**

- Verifying a one-line `ci.yml` addition: `git diff` (uncommitted) or `git diff <base>..HEAD`
  (once committed) to confirm exactly one added line and the adjacent lines untouched, plus
  `python3 -c "import yaml,sys; yaml.safe_load(open(...))"` for well-formedness — cheap and
  sufficient for a single-step YAML append.

## 2026-07-07 — Story NA-3 — Bootstrap gtm plugin config via /gtm:init

**Learnings:**

- Dispatch-prompt "locked decisions" outrank a plan's own verify commands when they conflict. The
  NA-3 plan's TG2 jq check (`.dependencies == ["postiz@postiz-agent", ...]`, flat strings) was
  stale relative to the spec/dispatch instruction that `plugin.json` dependencies mirror sdlc's
  `{name, marketplace}` object shape. Followed the dispatch instruction (object shape, verified
  with `[.dependencies[] | "\(.name)@\(.marketplace)"] == [...]`) since sdlc's actual manifest is
  objects, not strings — a literal string array would be inconsistent with the only other
  plugin.json in the repo.
- "Vendored functional equivalent" should mean a genuinely adapted copy, not a literal branded
  copy: the sdlc scripts (session-key.sh/tmp-dir.sh/cleanup-tmp.sh/session-complete.sh) reference
  `SDLC_SESSION_KEY` and sdlc-specific commands (`/auto`, `/impl`, `refs/triage.md`) in comments —
  left as-is these would be misleading/wrong inside a standalone gtm package. Renamed the env var
  to `GTM_SESSION_KEY` and the sentinel to `GTM_SESSION_COMPLETE`, and rewrote the sdlc-specific
  prose to reference gtm commands instead. `session-key.sh`'s `CLAUDE_CODE_SESSION_ID` fallback is
  generic and needed no change.
- The repo's own portability-lint.sh only scans `plugins/sdlc` — running it against a new
  `plugins/gtm/` package is a no-op pass regardless of gtm's content. Don't rely on it as a real
  gate for a new plugin; ran the sdlc lint's individual grep checks by hand against `plugins/gtm/`
  for real coverage (no absolute paths, no broken `./${CLAUDE_PLUGIN_ROOT}`, no PII, no forbidden
  agent frontmatter, frontmatter completeness) in addition to the plan's literal TG8 steps.

**Pitfalls:**

- This dispatch's isolated worktree (`.claude/worktrees/agent-<id>`) is checked out on its own
  local branch (`worktree-agent-<id>`), NOT the named `feat/<STORY-KEY>` branch — because
  `feat/<STORY-KEY>` was already checked out in the shared main checkout by another process, and
  git refuses to check out the same branch in two worktrees. The Write tool enforces worktree
  isolation (blocks writes to the shared checkout path) but Bash does not — a `cd` to the shared
  checkout path silently let file writes land there instead of the isolated worktree. Caught this
  before committing (removed the accidental `plugins/gtm/` from the shared checkout) and instead
  fast-forwarded the isolated worktree's branch to `origin/feat/<STORY-KEY>` (`git merge --ff-only
origin/feat/<STORY-KEY>`) to pick up commits (the plan doc) that existed on the named branch but
  not yet on the worktree's local branch. Always verify `pwd` / `git branch --show-current` in the
  _default_ Bash cwd (no `cd`) before writing — never `cd` into the shared checkout path.

**Patterns:**

- For a new "standalone, zero-dependency-on-sibling-plugin" package, grep the whole new package
  tree for the sibling plugin's path (`plugins/<sibling>`) at the end, not just the vendored
  scripts subdir — provenance comments belong in the plan/spec docs, not inside the new package
  itself (even doc files under the new plugin's own `refs/`/`README.md` should stay free of the
  literal path).

## 2026-07-07 — Story NA-3 review fixes — /gtm:init atomicity + portability-lint multi-plugin scope

**Learnings:**

- "Atomic write, discard on failure" claims must be checked _before_ any finalize step starts
  moving files into their real paths, not after — an existence check placed after the `mv` block
  runs too late: by the time it fires, the "discarded" files are already live at their final repo
  paths, so the STOP message is a lie. The fix pattern is: gate-check → (pass) → finalize moves,
  never finalize moves → gate-check → rollback-message-that-doesn't-actually-rollback.
- When a multi-file finalize can't be made atomic with plain `mv` (no cross-file transaction),
  pick one file as the "completion marker" and move it _last_. Whatever file a re-init/guard reads
  to decide "does config already exist" should be exactly that last-moved file — that way a
  mid-finalize crash is always detectable and self-healing (guard sees "doesn't exist yet", so
  Step 0 treats it as a fresh/incomplete init rather than a corrupted one) instead of accidentally
  looking like a complete, healthy install.
- The repo's `tools/portability-lint.sh` had `../plugins/sdlc` hardcoded as its only scan root —
  adding a second plugin (`plugins/gtm`) silently made the lint a no-op for it. Fixed by looping
  over `plugins/*/` and refactoring the 7 checks into a `lint_plugin()` function taking the plugin
  root as a param; the shared `marketplace.json` JSON-validity check moved outside the loop (it's
  repo-level, not per-plugin) so it isn't redundantly re-checked once per plugin.
- `git remote get-url origin | sed -E 's#.*/([^/.]+)(\.git)?$#\1#'` silently mangles any repo name
  containing a dot (e.g. `context-mode.dev` → `dev`) because the capture group `[^/.]+` excludes
  dots entirely — it isn't a "last segment" extractor, it stops at the first dot from the right
  that isn't part of a literal trailing `.git`. Verified fix (`basename "${url%.git}"` — strip a
  trailing `.git` via parameter expansion first, then take the path basename) against SSH, HTTPS,
  and no-`.git`-suffix remote URL forms, and against a plain no-dot repo name, before trusting it.
- `grep -o '"name"[[:space:]]*:...' package.json` matches the _first_ `"name"` key anywhere in the
  file, including nested ones (e.g. inside `exports`, `bin`, or a nested `peerDependenciesMeta`
  block) — not necessarily the top-level field. `jq -r '.name // empty' package.json` is the
  correct top-level-only, JSON-aware extraction; the `// empty` guards against `jq` emitting the
  literal string `null` when the field is absent (verified against a JSON file lacking `name`).

**Pitfalls:**

- Same isolated-worktree-can't-check-out-the-named-branch situation as the initial pass (see the
  entry above) recurred on this review-fix dispatch too — `git checkout feat/NA-3` failed because
  the shared main checkout already had it. Reused the same fix: stay in the default (non-`cd`'d)
  Bash cwd of the assigned worktree, and `git merge --ff-only origin/feat/NA-3` to fast-forward
  the worktree's local branch onto the remote branch's tip before editing anything. This is
  evidently a recurring characteristic of this project's worktree-per-dispatch setup, not a one-off
  — expect it on every dispatch for a story whose branch is also open in the main checkout.

**Patterns:**

- When a review finding says "root hardcoded to X, should scan all Y" for a lint/CI script, check
  whether any of the script's checks assume a _single_ root implicitly beyond the obvious `root=`
  var (e.g. a shared manifest check that should run once, not once per scanned unit) — collapsing
  everything into one blind per-unit loop over-scans some checks and duplicates their output.

## 2026-07-07 — Story NA-3 Copilot review fixes round 2 — lint regex + quoting hardening

**Learnings:**

- Assigned worktree was on the wrong local branch again (branch `worktree-agent-<id>`, `feat/NA-3`
  checked out only in the shared main checkout). Instead of `git merge --ff-only` (prior pattern),
  this time freed the branch by detaching the shared checkout (`git -C <shared-path> checkout
--detach`, safe since it was clean and at the exact same commit) then `git checkout feat/NA-3` in
  the assigned worktree. Both approaches work; detach-then-checkout is simpler when the shared
  checkout is clean and doesn't need to keep the branch ref itself.
- A review finding's own suggested regex fix can be under-verified. Finding: single-quoted ERE
  `[A-Za-z]:\\` (single backslash, meant to catch `C:\Users\...`) was proposed as a straight
  swap-in for the old (broken, double-backslash) pattern. Applying it verbatim broke the lint on
  _pre-existing, unrelated_ content: any prose containing an escaped-newline-in-a-doc-string like
  `"...exactly:\n  Status: ..."` or `"Criteria:\n"` also matches `letter:\` and false-positives as a
  "Windows path". Fixed by requiring the char before the drive letter be a non-letter (i.e. not
  mid-word): `(^|[^A-Za-z])[A-Za-z]:\\` — real paths are preceded by whitespace/quote/start-of-line
  (`" C:\Users"`), whereas the false positives are always mid-word (`...tly:\n`, `...ia:\n`) with a
  letter immediately before the "drive letter". Verified both the intended catch (`printf 'x
C:\\Users\\y\n'`) and the two false-positive shapes found in `plugins/sdlc/refs/*-playbook.md`
  and `skills/user-story/scripts/user-story-template.py` before trusting it.
- A fix that adds new legitimate content can itself trip an _unrelated_ existing lint check.
  Adding an SSH-remote-normalization snippet (`git@github.com:*` case-glob) to `product-detect.md`
  tripped check #3 ("no author emails / PII") because `git@github.com` is syntactically
  indistinguishable from a real email address to the generic `word@word.tld` regex. This is not a
  new lint bug — `git@github.com` genuinely looks like PII to a naive regex — so extended the
  existing allowlist (`grep -viE 'noreply|example\.|...'`) with `git@github\.com`, matching how the
  script already carves out other known-safe non-PII shapes (`noreply`, `your-org`) rather than
  weakening the base email regex itself.

**Pitfalls:**

- Always re-run the full lint/verification command after a "surgical" one-line regex fix, even when
  the fix looks obviously correct in isolation and matches the review finding's own suggested
  snippet — the surrounding repo's existing content is the real test bed, not just the reviewer's
  one example input.

**Patterns:**

- For "make detector X more precise" findings on grep-based lint scripts: after tightening a regex
  to catch more true positives, immediately grep the _whole_ scanned tree with the new pattern and
  triage every hit — don't assume the reviewer's one verification snippet is exhaustive.

## 2026-07-08 — Story NA-12 Phase 1-2 — vendored skill-creator + find-skills, wrote analyze-protocol.md

**Learnings:**

- Both upstream skills vetted clean. `skill-creator` (anthropics/skills, pinned commit
  `9d2f1ae187231d8199c64b5b762e1bdf2244733d`) ships its own per-skill `LICENSE.txt`
  (Apache-2.0, Copyright 2026 Anthropic, PBC) — carried verbatim, no modification needed.
  `find-skills` (vercel-labs/skills, pinned commit `4ce6d48ac44c8b637db87b2102fea3baca719df1`)
  has **no** per-skill or top-level `LICENSE` file upstream at this commit — only `package.json`
  `"license": "MIT"` and a README "## License / MIT" section declare it. Wrote a standard MIT
  `LICENSE` file for the vendored copy with a provenance footer explaining it was transcribed
  (not copied) from those two upstream sources, since there was no file to literally carry over.
- `find-skills`' `SKILL.md` is pure prose with **no bundled scripts** — it only tells the agent to
  invoke `npx skills find/add/check/update` (a public package-manager CLI querying the public
  skills.sh registry) — passes the "no exfiltration / no RCE / no secret access, confined to local
  files + public registry" checklist cleanly.
- **Follow-up (same day):** initially vendored `skill-creator` as `SKILL.md` + `LICENSE.txt` only
  per the plan's literal file list, flagging the dangling internal references (`scripts/*.py`,
  `references/schemas.md`, `assets/eval_review.html`, `agents/*.md`, `eval-viewer/*`) as a known
  scope gap. Coordinator follow-up confirmed the skill is non-functional without them and asked to
  vendor the full support tree. Re-cloned the same pinned commit
  (`9d2f1ae187231d8199c64b5b762e1bdf2244733d`) and copied all five referenced directories —
  `scripts/`, `references/`, `assets/`, `agents/`, `eval-viewer/` — verbatim (including the
  executable bits on the `.py` files). Did **not** skip `agents/` or `eval-viewer/`: re-reading
  SKILL.md's own "Reference files" section and Step 4 of the core loop shows both are core runtime
  dependencies, not optional/advanced-only — `agents/grader.md` is used every iteration (grading
  step), `agents/analyzer.md` is used every iteration (analyst pass) and also in the optional blind
  comparison, and `eval-viewer/generate_review.py` is invoked directly by SKILL.md as the mandatory
  viewer-launch step (repeated emphasis: "GENERATE THE EVAL VIEWER _BEFORE_ evaluating..."). Only
  `agents/comparator.md` is exclusively used by the explicitly-optional "Advanced: Blind comparison"
  section — vendored it anyway since it lives in the same small `agents/` directory as the two core
  files and splitting one file out of a 3-file directory for an "optional but harmless" doc isn't
  worth the inconsistency.
- Vetted every bundled script across all five directories, not just the ones read in the first pass (spec requires reading bundled scripts before vendoring): the `subprocess.run(["claude", "-p", ...])` calls in `run_eval.py`/`improve_description.py`, together with the `subprocess.run(["lsof", "-ti", ...])` and `os.kill(...)` calls in `eval-viewer/generate_review.py`, are local CLI/process-management invocations (not RCE from untrusted input, not exfiltration); `eval-viewer/viewer.html`'s `fetch()` calls only hit the local `/api/feedback` endpoint served by that same local script (same-origin, no external host). `aggregate_benchmark.py`, `generate_report.py`, `package_skill.py`, `quick_validate.py`, `utils.py` — grepped for network/exec primitives, no matches. No external network exfiltration found anywhere in the vendored tree.
- `git clone` works fine for vendoring even though this session's `curl`/`wget` are blocked by a
  context-mode hook (only for the http fetch path, not git's own transport) — used `git clone
--depth 50 <repo>` into the scratchpad, read files with the Read tool, then `rm -rf` the clone
  before committing (nothing scratchpad-sourced belongs in the final diff).

**Patterns:**

- For a "vendor a third-party skill" plan task, treat "SKILL.md + LICENSE only" and "the skill's
  full supporting directory tree" as two different, explicitly distinguishable deliverables — do
  not silently expand or contract the plan's stated file list based on what looks more "complete";
  record the resulting internal-reference gap in memory instead so the decision is traceable to
  the plan, not to an unstated assumption. Confirmed in practice: flagging the gap rather than
  guessing let the coordinator make the call explicitly, and the follow-up instruction ("check
  which directories are actually runtime needs, not just referenced") was answerable by re-reading
  the skill's own core-loop steps vs. its "Advanced"/optional sections — a skill's own structure
  usually tells you which bundled resources are load-bearing.

## 2026-07-07 — Story NA-3 PR review feedback — Postiz backend URL as config token, not a secret

**Learnings:**

- Two PR review comments (design-level, not bug-level) asked to reclassify one of two "env-var only"
  values as a persisted config token: the Postiz **backend URL** isn't a secret — the API **key** is.
  The fix touched 7 files (2 refs, 1 command, 1 agent, 1 README, 1 spec, 1 plan) because the old
  design had "only env-var names, never values" as a single blanket rule applied uniformly to both
  `POSTIZ_API_URL` and `POSTIZ_API_KEY` — splitting the two by sensitivity meant every place that
  stated the blanket rule, listed the two vars together, or gave a single combined STOP/checklist
  message needed independent treatment for URL vs key. A single grep for the shared token
  (`POSTIZ_API_URL`) across the whole plugin + both docs was necessary at the end to catch every
  place the old uniform framing had leaked in (schema tables, error-handling tables, "Decided"
  bullets, checklist prose, and even the downstream `product-marketing-manager` agent's "read
  project context" paragraph) — a per-file review would have missed at least one of these.
- Introducing a 3-source resolution ladder (existing config token → env var as _seed only_ → user
  prompt) for a value that used to be a flat "must be set in env" check requires explicitly writing
  a precedence rule, not just the ladder itself — otherwise it's ambiguous whether a later env-var
  change should silently override the persisted token on every run. Stated it explicitly everywhere
  the ladder appears: "config token is authoritative after first write; env var only seeds the
  _first_ resolution." Repeating the same precedence sentence at each of the 4 places (ref, command,
  README, spec) keeps a future reader from having to infer it from just the ladder order.
- A CLI that reads a value from an environment variable at run time doesn't dictate where that value
  is _sourced from_ upstream — `postiz` only ever sees `POSTIZ_API_URL` in its own process env, but
  gtm can still treat the value as a first-class persisted config token and `export` it into the
  session right before every CLI invocation. Don't conflate "the CLI's contract requires an env var"
  with "the value must be secret / env-only" — those are separate, independently-decidable design
  choices.

**Pitfalls:**

- Same isolated-worktree-can't-check-out-the-named-branch situation recurred yet again on this
  dispatch — `git checkout feat/NA-3` would have failed since the shared main checkout already had
  it open. Used the `git merge --ff-only origin/feat/NA-3` fix from the first NA-3 dispatch (not the
  detach-and-checkout variant from the second) since it was the simplest option available without
  touching the shared checkout at all.

**Patterns:**

- When a review comment says "let the user choose between two named options at init," model it as
  an explicit `AskUserQuestion` with exactly those two labeled options (not a free-text prompt with
  the options merely described in the question text) — this repo's other init flows (unless
  otherwise specified) use `AskUserQuestion` for every wallet-time either/or decision, so consistency
  with existing gate patterns (e.g. Step 0's re-init keep/merge/rerun choice for this same command)
  matters as a matching signal, moving to the AskUserQuestion primitive keeps the interaction model
  uniform across the plugin.

## 2026-07-08 — Story NA-12 Phases 3-5 — ai-enablement-engineer agent + /sdlc:analyze + init opt-in

**Learnings:**

- The GitHub-style anchor-slug rule matters when a spec mandates _exact_ anchor headings that two
  separate files must cross-reference: `## Drift / gap table` → `#drift--gap-table` (the `/` is
  stripped, leaving the surrounding spaces to collapse into a double hyphen) and
  `## Memory-conflict analysis & resolution` → `#memory-conflict-analysis--resolution` (the `&` does
  the same). Got both right by deriving the slug mechanically (lowercase → strip punctuation →
  spaces to hyphens) rather than guessing, then grepped the ref file itself for its own internal
  cross-references to confirm the derived slugs matched what was already in use there.
- When a plan phase says "mirror the shipped agent's shape" but the new agent's First-steps must
  also encode a hard gate the shipped agent doesn't have (here: STOP entirely if not Active, before
  even reading task instructions — vs. platform-engineer's softer "confirm with the user if
  Standby"), don't force the borrowed template's exact wording; keep the structural shape (numbered
  First steps, same section order) but let the gate's actual severity (STOP vs confirm) come from
  the spec's Error Handling table, since the two agents' ownership models are genuinely different
  (opt-in-gated vs always-active-in-repo).
- For a new domain agent that is _not_ a normal multi-select at init (gated by its own single
  opt-in instead), the cleanest place to wire it into `init.md` without touching the shared
  templates (`refs/agent-override-template.md`, `refs/project-context-template.md` — out of this
  phase's scope) is to give it a **self-contained, fixed override body inline in init.md itself**,
  explicitly called out as bypassing the stack-driven agent-domain-mapping/run-order tables those
  templates define for the other agents. This keeps the phase's diff scoped to the one deliverable
  file (`init.md`) while still producing a fully-substituted (`<project name>`/typecheck/test only)
  no-placeholder override on scaffold.
- "Mark the agent Active" needed no new boolean field anywhere: this repo's (and the plugin's)
  existing model treats presence of a workspace→agent row as the sole activity signal for every
  domain agent (no separate `Active: true` token exists in the template). Re-used that exact
  mechanism for `ai-enablement-engineer`'s opt-in instead of inventing a parallel activation
  concept — kept the ownership model's "single fact" claim (spec: "that single fact... is the
  entire ownership model") literally true instead of adding a second source of truth.
- Verified "no hard-coded area path in the write-scope resolution logic" (Phase 3 Step 9's own
  verify instruction) by grepping the finished agent file for the literal string `plugins/` and
  confirming every hit was either front-matter description prose or an explicit "e.g." illustrative
  example — never inside the ownership-resolution paragraph as the source of truth.

**Patterns:**

- Before writing a new agent/command that references anchors in a shared ref doc, `grep -n "^## "`
  the ref file first to get the literal heading list, then always link via `<ref>#<derived-slug>`
  using the _same_ derivation the ref file's own internal links already use (found by grepping the
  ref for its own `](#...)` occurrences) — cheaper and more reliable than trusting hand-derived
  slugs from memory of GitHub's algorithm.

## 2026-07-08 — Story NA-12 review fixes — dispatch-ladder slot, Active-definition centralization

**Learnings:**

- "Add the new agent to the classic 5-agent dependency order" review findings named only 2 of the
  3 occurrences in `principal-engineer-playbook.md` (~L133, ~L146) plus the Step-4 ladder — grepping
  the whole file for the repeated arrow-chain (`database-administrator.*platform-engineer.*sync-
engineer`) surfaced a third, unlisted instance inside the defect-path Phase-4 prose (~L212-213).
  Fixed all three for internal consistency rather than only the two literally named — a finding's
  line numbers are illustrative of the _pattern_, not necessarily an exhaustive location list; a
  repo-wide grep for the exact stale string is the cheap way to confirm nothing else matching the
  same defect was left behind.
- Renumbering a "Phase N — [agent] ..." ladder when inserting a new phase in the middle (after
  platform-engineer, before sync-engineer) requires renumbering every phase after the insertion
  point (3→4, 4→5, 5→6) — checked no other part of the same doc referenced those old phase numbers
  by number (the defect-path's own "Phase 1-4" debugging cycle is a separate, differently-scoped
  numbering scheme in the same file and must NOT be touched/renumbered).
- Centralizing a repeated informal definition ("Active") at its one canonical anchor
  (`analyze-protocol.md#ownership-resolution-rules`) only needs a same-file pointer-free fix for
  occurrences _below_ the definition in the same doc (scan-protocol's own "if not Active, STOP" step
  already reads correctly in-file without an extra cross-reference) — but occurrences in _other_
  files (`agents/ai-enablement-engineer.md`, `commands/analyze.md`) still need an explicit anchor
  link, since a reader of those files has no reason to already know where the definition lives.
- Two nearly-identical "Project skills (invoke via the Skill tool)" headings existed for
  `ai-enablement-engineer` (the live `.claude/project/agents/` override and the `init.md` scaffold
  template that generates it) listing skills that are actually preloaded via the agent's own
  front-matter `skills:` key, not runtime Skill-tool invocations like other agents' overrides. Fixed
  both to the same corrected heading/wording rather than picking one canonical file and drifting
  from it — a scaffold template and its generated artifact must stay textually identical or the next
  `/sdlc:init` regenerates the stale wording.

**Patterns:**

- When a review finding gives approximate line numbers (`~L###`) for "this pattern repeats", treat
  them as a starting point and grep the exact stale substring across the whole file before declaring
  the fix complete — under-fixing a few of N repeated occurrences reintroduces the same
  inconsistency the finding was raised to close.

## 2026-07-08 — Story NA-12 re-review — dispatch-ladder slot missed in sibling files

**Learnings:**

- A single grep scoped to one file (`principal-engineer-playbook.md`) is not a "grep the whole
  tree" pass — the same stale 5-agent enumeration existed independently in `tech-lead.md` (the plan
  agent's own "Execution order" ladder), `principal-engineer.md` (front-matter description, tag list,
  and its own execution-order ladder — 3 separate spots in one file), and `commands/plan.md` (the
  plan-doc phase list `tech-lead` is instructed to emit) — four files the playbook ref doesn't
  `grep -r` catch since each has its own independently-authored copy of the same ladder rather than
  including the ref. Fixed by repo-wide `grep -rn` across `plugins/sdlc/` for the exact arrow-chain
  and `Phase 1 —`/`[database-administrator]` substrings, not just the one ref file the original
  finding named.
- Not every hit on the "5 agent names co-occurring" grep is a dispatch-ladder enumeration needing
  the same fix: `refs/agent-override-template.md`'s run-order table and `refs/solutions-architect.md`'s
  "if X applicable" spec-section headers are structurally different (the override-template run-order
  table is explicitly out of scope for `ai-enablement-engineer` per its earlier phase's design — it
  uses a fixed, non-table-derived override — and the architect's conditional headers aren't an
  ordering/dispatch list at all). `refs/domain-agent-handoff.md`'s "Referenced from ..." sentence
  _did_ need the addition since `ai-enablement-engineer.md` genuinely references that ref (branch/
  memory/commit/return + pre-work checkout). Triage each hit against "is this actually a dispatch
  order, and does ai-enablement-engineer actually participate in/reference it" before editing —
  blind find-and-add-to-every-hit would have wrongly touched the override-template table.
- Auto.md's own "Phase 1 (Spec) / Phase 2 (Plan+Impl)" and the defect path's "Phase 1-4 (reproduce/
  root-cause/test/fix)" numbering schemes share the word "Phase" with the domain-dispatch ladder but
  are unrelated axes (workflow stage vs. debugging step vs. domain-agent order) — grepping bare
  `Phase 1` across the tree surfaces all three; only the domain-agent-order ones needed the edit.

**Patterns:**

- "Grep the whole plugin tree" instructions after a review finding should search for the _exact
  repeated substrings_ (the arrow chain, the bracketed tag list, the `Phase N — [agent]` line shape)
  across every file in the plugin, not just the one ref file a finding happened to cite — independent
  same-content copies (not `${CLAUDE_PLUGIN_ROOT}` includes) are exactly what make partial fixes
  drift out of sync with each other.

## 2026-07-08 — Story NA-12 PR #45 review round 3 — owner ruling reverses serial→parallel, contradiction fix, eval-viewer CDN hardening

**Learnings:**

- An owner ruling that reverses a design decision already landed in two prior commits
  (6086c34/c2b9477: ai-enablement-engineer as a numbered _serial_ Phase-3 slot) means "undo the
  numbering, don't just relabel it" — every file that had been renumbered up (Phase 3→4, 4→5, 5→6)
  needed renumbering _back down_ to the original 1-5, with ai-enablement-engineer pulled out of the
  numbered sequence entirely into its own unnumbered "MAY run in parallel" line placed after the
  ladder. Verified no dangling `Phase 6` references remained anywhere in `plugins/sdlc/` after the
  revert (grepped the literal string tree-wide) — a partial renumber-back would have been worse than
  the original bug (a still-wrong number instead of a consistently-wrong one).
- A "sequential only" rule needs its exception spelled out at the rule itself, not just implied by
  moving the parallel agent out of the numbered list — added "except ai-enablement-engineer, which
  may run concurrently... it consumes no artifacts from other domain agents" as a second bullet next
  to every "sequential only"/"ALL phases are sequential" rule statement (4 files), since a reader
  hitting the rule text alone (without noticing the separate unnumbered ladder line above it) would
  otherwise still conclude parallel dispatch is forbidden.
- Two consecutive review rounds gave literally opposite instructions for the same override heading
  (round 2: "annotate as plugin-bundled/front-matter-preloaded... no Skill-tool invocation needed";
  round 3: that phrasing now flagged as contradicting the agent's own First-steps, which _does_ say
  "invoke via the Skill tool" — fix to "plugin-bundled — invoke via the Skill tool", matching the
  platform-engineer override's convention wording). Resolution: front-matter preload and explicit
  Skill-tool invocation are not mutually exclusive (a skill can be both preloaded _and_ still
  explicitly invoked by convention) — added one sentence in the agent's First-steps making that
  explicit instead of re-litigating which claim is "more true"; the two rounds weren't actually
  contradicting each other, round 2 just used the wrong word ("no ... invocation needed") to express
  a scope claim ("also plugin-bundled") that round 3's own wording expresses cleanly.
- Vendoring-at-a-pinned-ref does not mean zero local modifications are ever allowed — the repo's own
  "no local forks for non-security issues, they belong upstream" policy (see this round's REJECTED
  Copilot findings on `skill-creator`'s Python scripts) has a security carve-out: `eval-viewer/
viewer.html`'s Google Fonts `<link>`s and `cdn.sheetjs.com` SheetJS `<script>` are a genuine
  supply-chain/no-network-exfiltration gap in the earlier NA-12 Phase-1-2 vet (which checked
  `subprocess`/`fetch()` in the `.py`/`.html` _script_ bodies but missed the static `<head>`
  `<link>`/`<script src>` tags loading third-party JS/CSS at render time — a vetting blind spot:
  "no exfiltration in the code" checks don't cover "loads third-party code via a static tag"). Fixed
  by removing the tags (system font-stack fallback; XLSX rendering degrades to a
  "preview unavailable offline" message via a `typeof XLSX === "undefined"` guard rather than
  crash), and recorded as a **documented local deviation** (not a silent fork) in a new "Local
  deviations" column on `plugins/sdlc/README.md`'s provenance table — the distinguishing factor
  from the rejected findings is CWE-driven (remote-code-loading risk) vs. style/robustness nits in
  vendored Python that belong upstream.
- Stray `</content>`/`</invoke>` tags at the tail of `docs/superpowers/plans/NA-12.md` were leftover
  tool-call artifact text from whatever process generated the plan doc (visible only by `tail`-ing
  the file — they don't show up in a normal Read unless you look at the very end) — a good reminder
  to `tail -5` any doc a review flags as having "stray content at end of file" rather than assuming
  a mid-file diff review would have caught it.

**Vet record update — `skill-creator` (pinned `9d2f1ae187231d8199c64b5b762e1bdf2244733d`):**
Re-vetted `eval-viewer/viewer.html` specifically for static `<head>` resource loads (not just script
`subprocess`/`fetch` calls, per the NA-12 Phase-1-2 vet's original scope). Found two remote loads:
`fonts.googleapis.com`/`fonts.gstatic.com` (Google Fonts CSS) and `cdn.sheetjs.com` (SheetJS
`xlsx.full.min.js`, SRI-pinned but still a remote JS load). Both removed as a documented local
deviation (see README provenance table); no other bundled file in the `skill-creator` tree loads
remote resources (re-confirmed via `grep -rn "https://" eval-viewer/` → zero hits post-fix). The 4
Copilot findings on `run_loop.py`/`quick_validate.py`/`package_skill.py` remain correctly rejected
(non-security robustness/dependency nits in vendored-verbatim Python — belong upstream, not a local
fork).

**Patterns:**

- When a review finding says "X may run in parallel because it consumes no artifacts from other
  agents," treat that as a structural claim about the _data-flow dependency graph_, not just a
  labeling change — an agent with no upstream artifact dependency shouldn't be slotted into any
  numbered serial position at all (not even a placeholder "Phase N (parallel)"), because a numbered
  slot visually implies "waits for N-1" to a future reader; pull it out of the list entirely into
  its own annotated line.
- When vetting a bundled third-party asset for "no exfiltration/no remote code," explicitly check
  static resource-loading tags (`<link href=... rel=stylesheet>`, `<script src=...>`, `<img src=...
http...>`) as a _separate_ pass from checking script logic (`fetch`/`subprocess`/`exec` calls) —
  the two are different vetting axes and a script-logic-only pass will miss a static tag pointing at
  a CDN.

## 2026-07-08 — Story NA-12 high-effort workflow review — 10 confirmed defects, owner "dependency-free" clarification

**Learnings:**

- "Parallel" as a review-round shorthand can itself be the bug: round 3's fix made
  ai-enablement-engineer a genuine concurrency exception ("MAY run in parallel," "sequential only
  ... except..."), but the owner's actual intent was narrower — no _dependency ordering_ (it may be
  slotted anywhere in the ladder), not no _serialization_ (exactly one domain agent still writes the
  story branch at a time — the git single-branch/worktree constraint and Step-5 HEAD-advance check
  don't go away). Reworded every spot from "MAY run in parallel with any phase" to "dependency-free:
  may be dispatched at any point in the ladder ... but still runs alone, one domain agent at a time"
  and made "sequential only — never two domain agents at once" universal again (no exception
  clause) — the exception is about _order_, not _concurrency_. A one-word review shorthand
  ("parallel") that seemed unambiguous in isolation turned out to conflate two genuinely different
  properties (freedom from ordering vs. freedom from mutual exclusion); worth re-deriving the
  precise claim from the owner's own justification sentence ("consumes no artifacts... nothing
  consumes its") rather than trusting the shorthand label alone, even on a second pass.
- A "defined exactly once" charter (analyze-protocol.md's own stated purpose) is violated not just
  by copy-pasted prose blocks but by _independently drifting restatements of the same fact_ — the
  clearest tell was commands/analyze.md's Default-mode step 1 and agents/ai-enablement-engineer.md's
  First-steps step 1 each hard-coding their own version of the "not Active" report message
  ("AI-config management not enabled; run /sdlc:init to opt in."), which had already silently
  diverged from the corrected canonical message written into the new Error-handling table
  ("repo not opted in or project-context unreadable — run /sdlc:init."). Fixed by grepping the
  literal old message string tree-wide after adding the canonical table, not just checking the
  table itself was correct — a dedup pass isn't done until every duplicate copy is gone, including
  ones embedded as inline strings inside otherwise-unrelated operational steps (not just the
  obviously-duplicated table/list blocks the review named).
- "Move X to a canonical location and reference it by anchor" needs a same-file check too:
  `refs/analyze-protocol.md`'s own Scan-protocol step 2 restated the old (now-wrong) "not Active"
  message inline, in the _same file_ as the new canonical Error-handling table three headings below
  it — proximity to the canonical source doesn't prevent drift; every restatement needs the same
  grep-and-replace treatment regardless of which file it lives in.
- A branch-before-commit reorder for a _standalone_ apply path must explicitly say what _dispatched_
  mode does instead (nothing — it commits on the already-checked-out impl branch), otherwise a
  reader might assume the new "branch first" step applies universally and try to branch mid-dispatch
  (which would violate the domain-agent-handoff.md contract of never creating a branch). Every
  reorder edit paired the standalone step with an explicit "dispatched mode does not branch here"
  sentence.
- Init.md's row-writes for a newly-opted-in agent needed a "does the target directory exist"
  precondition that the original design silently lacked — same failure shape as writing a
  workspace→agent row for a path that doesn't exist yet, which the plugin's own drift/gap table
  already flags as a check ("Workspace→agent table vs disk: Table lists a path that no longer
  exists"). The fix (write conditionally, keep ≥1 row for the Active signal, document a root-level
  fallback) had to reference that pre-existing drift check by name to make clear _why_ an
  unconditional write was wrong, not just assert the new conditional behavior.
- A python HTML-report generator (`generate_report.py`) embeds its whole template in one
  triple-double-quoted string built via `"""..." + var + """..."""` concatenation — safe to strip
  `<link>` tags and swap `'Poppins'`/`'Lora'` font-family values (they're just text inside the
  string, single-quoted, no nesting conflict with the outer `"""`), but must re-run `python3 -m
py_compile` afterward rather than assume "it's just editing text inside a string" is risk-free —
  a stray literal `"""` or unbalanced quote inside the edited text would silently break the module
  at import time, not at template-render time.

**Patterns:**

- When a review defines a domain-agent property with a precise causal justification ("it consumes
  no artifacts from other domain agents and nothing consumes its"), treat that justification
  sentence — not the one-word label the previous round used — as the actual spec to reword every
  occurrence against; a label alone (parallel/dependency-free/concurrent) is lossy compared to the
  underlying claim and different rounds can legitimately mean different things by the same word.
- After finishing a "canonicalize X, replace duplicates with anchor refs" pass, grep the _exact old
  literal string_ (not just the structural pattern) across the whole plugin tree as a final check —
  this catches both cross-file copies and same-file restatements a structural/anchor-based search
  would miss (an anchor reference makes copy #1 correct without touching copy #2 that used the same
  words but not the same anchor).

## 2026-07-12 — Story NA-25 — wire skill-preload regression guard into CI

**Learnings:**

- `.github/workflows/ci.yml` isn't listed in project-context.md's workspace→agent table at all
  (only `tools/`, `brand/`, `apps/marketing*`, `packages/ui/`, plugins-family paths are), but the
  dispatch explicitly framed it as platform-engineer-owned "infrastructure" — CI wiring is a
  reasonable default landing spot for an unlisted infra path when no other agent's table row
  covers it, distinct from touching the _content_ being gated (the guard script itself, under
  `plugins/sdlc/scripts/`, stayed strictly off-limits per the dispatch's explicit "not your
  surface" instruction even though platform-engineer's override says "never: plugins/").
- The new guard step (`check-agent-skill-preloads.sh`) is _intentionally_ red right now — 12
  agents still declare frontmatter `skills:` — and CI's `main` job has no `continue-on-error`
  convention anywhere else in the file. Wiring it in as a normal blocking step (not soft-failed)
  matches the story's own framing ("fails while any agent declares... a later phase converts
  them, turning the guard green") — the red state is expected and by design until that later
  phase lands, not a bug to work around here.
- Verifying a single-line YAML append stays parseable is cheap and worth doing even for a
  "trivial" edit: `python3 -c "import yaml; yaml.safe_load(open(...))"` plus checking
  `jobs.main.steps[-1]` catches indentation drift (e.g. accidentally nesting under the previous
  `run:` block) that a visual diff read alone might miss.
