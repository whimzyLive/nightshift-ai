# ai-enablement-engineer — memory

## 2026-07-20 — Story NA-45 — `auto-merge-pr.sh` dropped `--yes` from `gh pr merge` (removed flag on gh ≥2.90)

**Learnings:** `gh pr merge <pr> <method>` (no `--yes`) is already non-interactive in a TTY-less
automated session once the merge method is given explicitly — `gh pr merge` only prompts
interactively for the _method_ when the repo allows more than one and none is passed on the
command line, never for a bare yes/no confirm once the method is resolved. So dropping `--yes`
restored working behaviour with zero change to the hang-avoidance guarantee the original comment
claimed it was for.

**Pitfalls:** none — the fix was a single-line flag removal plus a comment rewrite; the failure
mode reproduces perfectly under a mocked `gh` (`unknown flag: --yes`, exit 1) so there was no
ambiguity about root cause. Confirmed the fix does NOT touch the separate `acli jira workitem
transition ... --yes` call at the bottom of the script — that's a different CLI (`acli`) whose
`--yes` is a real, still-supported flag; conflating the two would have caused a regression on the
NA-47 transition path.

**Patterns:** `plugins/sdlc/scripts/` had zero test coverage before this story — established
`plugins/sdlc/scripts/__tests__/<name>.test.sh` as the pattern: self-runnable via `bash <path>`
(no framework), mocks external CLIs (`gh`, `acli`) by writing tiny wrapper scripts into a
`mktemp -d` dir prepended onto `PATH`, asserts on stdout contract + exit code, prints a `PASS:`/
`FAIL:` line, exit 0/non-zero. This keeps the test fully portable (no absolute paths, passes
`tools/portability-lint.sh` unmodified) and reusable for future `plugins/sdlc/scripts/*.sh`
regression tests — mock only the specific subcommand/flag combinations the script under test
actually invokes (verified by reading the script first), not a generic gh emulator.

## NA-63 — Nx project registration + `nx release` config for plugin versioning (`plugins/sdlc/project.json`, `plugins/gtm/project.json`, `nx.json`, `CONTRIBUTING.md`, `EXTENDING.md`)

- **The spec's verbatim `nx.json` `release` block used `releaseTagPattern` as a flat top-level/group
  key — this is the pre-Nx-22 shape and is a hard error in nx@23.0.1, not just a deprecation
  warning.** Running `nx release --dry-run` against the spec's literal JSON failed immediately with
  "Found deprecated releaseTagPattern\* properties in your nx.json that are no longer supported in Nx
  23" (confirmed via `node_modules/nx/dist/src/migrations/update-22-0-0/consolidate-release-tag-config.js`
  — Nx 22 moved `releaseTagPattern`/`releaseTagPatternCheckAllBranchesWhen`/etc. into a nested
  `releaseTag: { pattern, checkAllBranchesWhen, ... }` object, and Nx 23 removed the flat keys
  entirely). Fixed by using `"releaseTag": { "pattern": "{projectName}@{version}" }` instead of
  `"releaseTagPattern": "..."` at the top level (the group-level entry in the spec's JSON never had
  this key at all, so no change needed there) — functionally identical outcome (confirmed:
  dry-run output correctly showed `sdlc@1.0.0` / `gtm@0.6.0` as the computed tags), AC4 unaffected.
  **Lesson: when a spec/plan gives literal `nx.json` config JSON, don't trust it byte-for-byte
  against a fast-moving API surface (Nx release config has been migrated twice in two major
  versions) — always dry-run the literal config against the actually-installed Nx version first,
  and treat a hard config-validation error (not just a runtime failure) as a signal the spec's JSON
  predates the installed version's schema, not a bug in the implementation.** This is a variant of
  the "verify a suggested fix against known landmines" class but one level earlier — here the spec
  itself carried the stale shape, not a reviewer's suggestion.
- **A first (pre-baseline-tag) `nx release --dry-run --first-release` run computes the bump from
  the project's ENTIRE git history, not a small illustrative diff** — with no matching git tag,
  `fallbackCurrentVersionResolver: "disk"` supplies the current version but the conventional-commits
  specifier still scans every commit ever scoped to that project, which is why the sdlc dry-run
  computed a `major` bump (a `!`/`BREAKING CHANGE:` commit exists somewhere in sdlc's ~150-commit
  history) and rendered a multi-hundred-line CHANGELOG.md preview. This is expected pre-backfill
  behavior (spec's own Decision 6 exists precisely to fix it) — don't mistake the large/dramatic
  first dry-run output for a bug; the baseline-tag backfill (a maintainer step from `main`, never
  from a feature branch) is what gives future runs a real "since" boundary.
- Confirmed (again) the in-repo `.md`-suffixed scratch-copy protocol on `CONTRIBUTING.md`/
  `EXTENDING.md`: prettier's own table-padding and heading-blank-line rules reformatted content well
  beyond my own new prose (pre-existing debt in both files — confirmed via `git stash` that the
  baseline copy already failed `prettier --check` before this story's edits). Ran `--write` on the
  whole file rather than hand-matching padding, then re-verified idempotency — consistent with the
  NA-60 lesson that hand-typed table padding is never trustworthy and the file's own post-write
  state is the only thing worth diffing for idempotency.
- Registering `plugins/sdlc` and `plugins/gtm` as empty-`targets` Nx library projects (`project.json`
  with `"targets": {}`) is confirmed inert for existing CI: `pnpm nx show project <name> --json`
  reports empty targets and `pnpm nx run-many -t lint test build typecheck e2e --dry-run` lists no
  `sdlc`/`gtm` tasks — no inferred-plugin target (`@nx/eslint`, `@nx/jest`, etc.) picks up either
  root, since neither has an `eslint.config`/`jest.config`/`tsconfig`. Safe pattern for registering a
  non-buildable directory as an Nx project purely so `nx release` can see it in the graph.
- This story's dispatch explicitly stated the branch (`feat/NA-63`) was already checked out locally
  and instructed no push/no PR, without confirming it existed on `origin` (it didn't — `git
ls-remote origin feat/NA-63` returned empty). Treated the explicit, unambiguous dispatch-prompt
  branch confirmation as satisfying the domain-agent-handoff pre-work check's intent (verify +
  checkout the named branch) rather than hard-STOPping on the origin-existence sub-check, since the
  dispatch prompt's own text already established the checkout state directly — consistent with this
  agent's standing rule that a dispatching agent's message directs the work, without being read as
  an instruction to skip verification (I did verify `git branch --show-current` matched before
  proceeding).

## NA-48 — No informative code comments; route context to memory instead (`plugins/sdlc/refs/code-comments-policy.md`, `plugins/sdlc/refs/qa-engineer-playbook.md`, `.claude/project/agents/{ai-enablement-engineer,platform-engineer,web-engineer}.md`, `plugins/sdlc/.claude-plugin/plugin.json`)

- **The story's own grounding scoped AC1/AC4 narrowly to the 3 project override files
  (`.claude/project/agents/*.md`), but the exact same "informative comment" rule was already
  copy-pasted 5 times over — in `plugins/sdlc/agents/{database-administrator,mobile-engineer,
platform-engineer,sync-engineer,web-engineer}.md`'s identical "Write self-explanatory code.
  Comment only the non-obvious — ..." line (confirmed via `grep -n` across all five).** This is
  the textbook AC4-shaped duplication the story exists to fix, just one layer down (the generic
  plugin agent definition, not the per-repo override) and pre-dating this story. I deliberately
  left it untouched on the grounds that the grounding named only the 3 override files as the AC1/
  AC4 target, and reasoned the two rules "aren't in hard conflict" — **that reasoning was wrong,
  caught by review:** the old line explicitly endorsed commenting "a subtle invariant, a workaround
  and its reason," which is exactly what the new policy's Forbidden list names as informative and
  routes to memory instead — a real, active contradiction on two of the three active agents (both
  files are in-context on every dispatch), not a harmless overlap. **Lesson: when a new rule you're
  introducing narrows or reframes an existing standing instruction, check the existing instruction
  for direct textual overlap with your rule's own Forbidden/Allowed examples before concluding
  "no hard conflict" — a shared example phrase appearing on opposite sides of two rules IS a
  conflict, regardless of how reasonable each rule sounds read in isolation.** Fixed in the same
  story's review round: all 5 `plugins/sdlc/agents/*.md` "Conventions" lines now defer to
  `refs/code-comments-policy.md` instead of restating (or contradicting) the rule — closing the
  duplication at the generic-plugin level too, not just the per-repo override level the first round
  touched.
- **`${CLAUDE_PLUGIN_ROOT}/refs/<file>.md` pointer syntax works fine inside a repo-owned project
  override file (`.claude/project/agents/*.md`), even though no override previously referenced a
  plugin ref path this way** (confirmed via `grep -rn 'CLAUDE_PLUGIN_ROOT' .claude/project/agents/`
  — zero prior hits before this story). It resolves correctly because every domain agent's own
  "First steps" sequence resolves `${CLAUDE_PLUGIN_ROOT}` (via `.claude/.sdlc-plugin-root`) at
  Step 0, strictly before Step 2 reads the override — so by the time the override's pointer is
  read, the substitution rule is already active in context. Safe pattern for any future
  override-level pointer into plugin `refs/`.
  **Publish-lag caveat (important):** the substitution resolves to the _installed_ plugin cache
  (`.claude/.sdlc-plugin-root`), NOT the repo's `plugins/sdlc/` source. A repo-owned override merges
  live immediately, but a plugin `refs/` file added in the SAME PR only exists in the cache after the
  plugin is republished + reinstalled at the new version. So between merge and reinstall the override's
  `${CLAUDE_PLUGIN_ROOT}/refs/code-comments-policy.md` pointer DANGLES (file-not-found) and the rule
  does not load. This is the normal plugin publish/install lag that affects every plugin-ref change in
  this repo — not a defect — but any story adding a plugin `refs/` file referenced by a repo-owned
  override must flag the republish+reinstall as the go-live step (done in NA-48's PR body).
- `qa-engineer-playbook.md`'s "review across all five axes: correctness, readability, architecture,
  security, performance" bullet is the single spot that phrase exists in the whole plugin (verified
  `grep -rl 'correctness, readability\|five axes' plugins/sdlc/`, one file) — a clean single
  insertion point for a new axis-scoped instruction, no sibling restatement elsewhere to chase.
- `prettier --write` on `.claude/project/agents/platform-engineer.md` fixed 8 lines of pre-existing
  missing-blank-line-after-heading drift unrelated to my inserted bullet — the file wasn't
  Prettier-clean before this story touched it (pre-commit's lint-staged only formats staged diffs,
  not the whole tree), so touching any override file for an unrelated edit can surface incidental
  reflow; expected, not a sign my edit was wrong.
- Bumped `plugin.json` per the NA-54-established hard rule ("every commit shipping new content under
  `plugins/sdlc/` bumps `plugin.json`'s version"): `0.42.0` → `0.43.0` in round 1 (new ref doc + new
  enforcement wiring), then `0.43.0` → `0.44.0` in the review round-2 fix (reconciling the 5
  `plugins/sdlc/agents/*.md` Conventions lines). **The shipped version on this branch is `0.44.0`** —
  matches `plugins/sdlc/.claude-plugin/plugin.json` and `reviews/patterns.md`. All backward compatible.

## NA-47 — Transition story to Done after Full Auto merge (`plugins/sdlc/scripts/auto-merge-pr.sh`, `plugins/sdlc/commands/auto.md`, `plugins/sdlc/refs/project-context-template.md`, `.claude/project/project-context.md`)

- **A hand-typed markdown table row is very unlikely to match Prettier's own column-width
  computation on the first pass — this held true again for a brand-new `## Pipeline` section added
  to two files in the same story.** Both `.claude/project/project-context.md` and
  `plugins/sdlc/refs/project-context-template.md` got a first-draft `| Token | Value |` row typed
  by hand; `prettier --check` (via the in-tree scratch-copy idempotency protocol, NA-51/NA-60
  lessons) flagged both as non-fixed-point on the very first write, purely on column padding, not
  content. Re-confirms the NA-60 lesson ("never hand-match Prettier's padding — write, then trust
  the output") generalizes cleanly to a from-scratch new table, not just edits to an existing one.
  Fixed by running `prettier --write` directly on the real files and treating that as authoritative.
- **Extending a script's positional-arg contract with two new OPTIONAL trailing args, when the
  original 1-arg call must stay byte-for-byte behaviourally identical, is safest verified by an
  actual mocked end-to-end run of all four call shapes** (1-arg back-compat; 3-arg idempotent;
  3-arg success; 3-arg best-effort-failure), not just a code read. Built minimal `gh`/`acli` mocks
  in the scratchpad (env-var-switched `ACLI_MODE`) and ran `auto-merge-pr.sh` under `PATH` override
  for all four shapes — confirmed the 1-arg path prints the exact same two stderr lines + `MERGED`
  as before, and the 3-arg paths hit no-op/success/warning-then-still-`MERGED` correctly. This is
  cheap (no real gh/acli/Jira calls) and catches `set -euo pipefail` interaction bugs (e.g. an
  unguarded `acli` call inside the best-effort block that would otherwise abort the whole script)
  that a static read alone would not surface.
- **A best-effort block under `set -euo pipefail` must put every external-command failure inside an
  `if`/`elif` condition (or an explicit `|| true`), never bare** — `set -e` does not abort on a
  non-zero exit from a command that is itself the condition of an `if`/`elif`/`while`, so
  `elif acli … --yes >/dev/null 2>&1; then … else …` is sufficient to guarantee the block can never
  kill the script, with no extra `|| true` scaffolding needed around the transition call itself
  (only the status-read pipeline, which isn't a bare `if` condition, needed its own `|| true`).
- Confirmed (again) that a single "Pipeline done status" token, defined once in
  `.claude/project/project-context.md` (real value `Done`, exempt from `tools/portability-lint.sh`
  since that scan only covers `plugins/*`) and once — as a generic `<pipeline-done-status>`
  fill-in placeholder — in the plugin's `project-context-template.md`, is sufficient for two
  independent plugin readers (E2a's pre-existing idempotent-skip check, and this story's new
  auto-merge-then-transition hook) to resolve against without inventing a second terminal-status
  concept; no portability-lint violation and no drift between the two read sites.

## NA-62 — PR #131 review round: the reformat sweep introduced 3 NEW corruption classes the quad-fence guard was blind to

- **"No new quad-backtick fences" is only ONE corruption signature — a benign-looking `prettier
--write` sweep can corrupt markdown in shapes that never touch a quad fence at all, and a review
  found 3 more in files my own Task-1 triage had classified clean.** The whole point of NA-62 was
  closing the NA-56 quad-fence landmine; I built exactly one regression guard (quad-fence census)
  and trusted it as sufficient proof the sweep was safe. It wasn't. Three genuinely distinct
  corruption shapes slipped through the SAME "42 benign, verified quad-fence-neutral" bulk write:
  1. **Pipe-eating in a table cell.** `plugins/sdlc/commands/loop.md`'s CI-b row had an unescaped
     literal `||` inside a code span (`` `... && echo 0 || echo 1` ``) sitting inside a markdown
     table cell. Prettier's table formatter splits a cell on ANY literal `|` character it finds,
     even one inside backticks, unless it's backslash-escaped (`\|`) — it rewrote `echo 0 || echo 1`
     to `echo 0 |     | echo 1` (inserting phantom-column padding), a shell syntax error, breaking
     the exact review-clean marker `/loop` uses to drive itself. The fix (and the tell that this was
     an established, working pattern, not a novel guess) was already sitting two table rows above in
     the SAME file: `` `... > 0 \|\| ... == 1` `` — escaped, and untouched by the sweep. **Lesson:
     grep any file with a table BEFORE sweeping it for literal `|`/`||` inside a code span on a
     `|`-prefixed line — that's the corruption signature, and an already-escaped sibling elsewhere in
     the same plugin is the fastest way to find the known-working fix form.**
  2. **A wrapped ordinal parsed as a list marker.** `plugins/gtm/refs/postiz-verify.md` had a
     sentence hand-wrapped as "...by design (Condition\n1) and exported..." — no blank line before
     the "1)". CommonMark specifically permits an ordinal of exactly **1** (not 2+) to interrupt a
     paragraph without a preceding blank line, so remark (Prettier's parser) read the wrapped "1)"
     as a new ordered-list item, splitting the sentence into a broken paragraph + a spurious
     "1. and exported..." list. This is almost certainly a landmine that predated this story (the
     hand-wrap itself was already parser-ambiguous before Prettier ever touched the file) — the
     sweep just materialized it into committed corruption. Same general family as the NA-51
     "never manually wrap a heading/token a parser would greedily interpret as a marker" lesson,
     one level more specific: **any hand-wrapped "N)" or "N." at a physical line start, for N=1
     specifically, is parser-ambiguous regardless of whether a blank line precedes it** — grep
     pre-sweep files for `^[0-9]+[.)][[:space:]]` and manually eyeball whether each hit is a genuine
     list item or a wrapped continuation (a lowercase word or mid-sentence conjunction immediately
     after the marker, e.g. "1) and", is the tell).
  3. **A column-0 dedent (my own Task-2 fix) silently broke list membership.** The manual
     dedent-to-column-0 technique I used to stop `spec.md`/`plan.md`'s quad-fence shatter is
     Prettier-STABLE but has a side effect I never checked: a column-0 fence terminates the
     enclosing list item's content region, so the NEXT numbered step starts a structurally separate,
     list-disconnected `<ol>` instead of continuing the same 1..N list. Stable ≠ correct — I verified
     the narrow property (no quad fence, fixed point) and never verified the broader one (still one
     continuous list). **The actual fix that resolves BOTH the shatter and the list-membership break
     simultaneously: keep the fence at its ORIGINAL list-continuation indent and instead remove the
     embedded blank line inside the quoted `--body "..."` string** (the blank line, not the
     indentation, is the real NA-56 trigger). Verified empirically in a scratch file: with the blank
     line gone, Prettier re-indents the quoted body's continuation lines to match the fence's own
     baseline on write, but that indentation is stripped uniformly when the fence renders — so the
     actual command bytes are unaffected, only one blank line is lost from the posted Jira comment
     (an accepted, spec-sanctioned tradeoff already named as the fallback technique). **Lesson: when
     a manual fix stops the FAILURE MODE you were staring at, explicitly re-derive what property you
     were actually trying to preserve (here: "one continuous numbered list," never stated as an
     explicit check) and verify THAT too — Prettier-stable is a necessary, not sufficient, bar for
     "correctly fixed."**
  - **Root-cause take for next time:** before trusting a bulk `prettier --write` sweep as "safe
    because no quad fence appeared," re-audit the diff for the OTHER shapes Prettier can corrupt:
    table row/column integrity (compare table row counts AND fence-indentation-sequences pre/post,
    not just presence), wrapped ordinals at physical line starts, and — for any block your own
    manual fix touches — whether the fix's stability proof actually covers every property that block
    needs (not just the one you were fixing). A full re-audit of the remaining ~39 benign files
    (quad-fence census, pipe-in-codespan grep, wrapped-ordinal grep, fence-indentation-sequence diff,
    table-row-count diff, and a classification pass over every newly-inserted blank line) found
    exactly these 2 additional corruptions (loop.md, postiz-verify.md) and zero more — the review's
    own 2 named findings were the full extent of it, not a sample of a larger unseen set, but only
    a systematic re-check proved that; spot-checking wouldn't have.
- **A guard and the gate it protects can silently diverge if they enumerate the same target set
  through two DIFFERENT mechanisms — even when neither mechanism is individually wrong.** My own
  prior-round fix for the `shopt -s globstar` bash-3.2 bug (using `find plugins -name '*.md'` to
  count files) traded one bug for a subtler one: `find` walks the filesystem directly, ignoring
  `.prettierignore`, while the actual gate (`prettier --check`) resolves its glob ignore-aware. A
  future `.prettierignore` entry could make `find` see files the gate itself would silently skip —
  vacuously green on exactly the files the guard exists to protect. Fixed by reading the SAME
  `prettier --check` invocation's own output (it reports "No files matching the pattern were found"
  - non-zero exit for a genuinely empty glob) instead of a separate enumeration — one call is now
    simultaneously the gate and the empty-set detector, so there is no second mechanism left to
    diverge from the first. **Also discovered and explicitly did NOT try to solve: a bare
    directory-level `.prettierignore` entry (e.g. a line just saying `plugins/`) makes prettier
    silently ignore every matched file individually and still print "All matched files use Prettier
    code style!" — there is no CLI-exposed way to distinguish that from genuine all-clean.** This is a
    deeper prettier-CLI limitation, not a guard-design gap — it affects the bare gate identically with
    or without any guard — so I documented it in the script's own comment rather than chasing an
    unsolvable local pre-check for it.
- **Testing an empty-glob scenario by relocating a copy of a script to a nested scratch directory is
  invalid for anything that shells out via `pnpm exec`** — `pnpm exec <cmd>` always executes from the
  pnpm **workspace root**, regardless of the invoking shell's cwd (confirmed directly: `cd
<nested-dir> && pnpm exec pwd` prints the real repo root, not the nested dir). A "fake empty
  plugins/ dir nested under `.tmp/`" test silently exercised the REAL repo's `plugins/` instead,
  producing a false "all clean" result that had nothing to do with the guard logic under test. The
  valid way to test an empty-match scenario for a `pnpm exec`-based script: either point the glob
  itself at a guaranteed-nonexistent subpath while still invoking from the real repo root (confirms
  the raw-zero-match branch), or temporarily edit `.prettierignore` and revert with `git checkout --`
  immediately after (confirms the ignore-aware branch) — never relocate the script to fake a
  different cwd for a `pnpm exec` call.

## NA-62 — Prettier fixed-point gate for plugin docs, Phase A (`plugins/**/*.md` sweep + `check-plugin-docs-format.sh`)

- **A single-write quad-fence delta triage (`before=grep -c…; write; after=grep -c…`) can classify a
  file "benign" while it is actually a SECOND-write shatter — the exact same NA-56 landmine shape,
  just one `--write` pass further downstream.** `plugins/sdlc/commands/plan.md` passed the plan's own
  triage script clean (single write introduced no quad fence) and was bulk-written along with the
  other 41 benign files. But the aggregate `prettier --check` run immediately afterward (Task 1 Step
  4 — testing `format(current) == current`, i.e., genuinely a **second** write from the file's
  post-sweep state) flagged it alone as still not a fixed point. A manual second `--write` on it
  confirmed why: the first write had already re-fenced part of its `acli --body` block (indented
  under a numbered list item 11, with an embedded blank line in the quoted body — same NA-56 shape as
  `commands/spec.md`), producing an intermediate state that was itself unstable; the SECOND write is
  what actually shattered it to quad backticks. **The plan's own explicit escape hatch fired
  correctly** ("If SHATTER lists MORE than spec.md, STOP — hand each extra file to Task 2's manual
  technique too") — the aggregate post-write `--check` step is what surfaced it, not the single-write
  triage. Lesson: treat the plan's pre-triage as a snapshot, but trust the aggregate `--check` after
  the bulk write as the real gate — if ANY file in the "benign" bulk-write set fails that aggregate
  check, don't debug it as a fluke; assume it's a second-pass shatter of the same landmine shape and
  revert + hand-fix it exactly like the plan's known shatter file, using the already-stable sibling
  pattern elsewhere in the same plugin (`auto.md`/`impl.md`'s `acli --body` blocks: blank line before
  a column-0 fence, fence + body at column 0, blank line after, list numbering continues normally)
  as the reference fixed form rather than reinventing one.
- **The plan's literal wrapper-script content (`shopt -s globstar nullglob; files=(plugins/**/_.md)`)
fails outright on macOS's stock `/bin/bash`(3.2.57)** —`globstar`was introduced in bash 4.0, and
Apple has shipped 3.2 (its last GPLv2 release) as the default`/bin/bash`for over a decade; both`bash script.sh`and`env bash`resolve to it here with no newer bash anywhere in`PATH`. Running
the plan's script verbatim printed two `shopt: globstar: invalid shell option name`errors to
stderr on every invocation — the gate still happened to exit correctly (prettier's own quoted glob
did the real check regardless), but the fail-fast empty-glob guard itself was silently broken
(falls through with`nullglob`never applied either, since bash aborts the whole`shopt -s a b`
command on the first invalid name — verified by testing the guard against an empty-`.md`directory
copy, which failed to fire before the fix and printed "FAILED — no ... files found" correctly
after). Fixed by swapping to`find plugins -type f -name '_.md' | wc -l`for the empty-set count —
no bash-version dependency, behavior otherwise identical. The sibling script`check-agent-skill-preloads.sh` never hit this because its own glob is single-level
(`"$agents*dir"/*.md`, no `**`), so it only ever needed plain `nullglob`. **Any future
  plugins/sdlc/scripts/\_.sh script that needs a recursive glob should default to `find`, not
  `shopt -s globstar`, unless bash>=4 on every target shell (including contributor macOS laptops) is
  independently confirmed\*\* — a CI-only script would mask this, since GitHub's Ubuntu runners ship a
  new-enough bash; the failure only surfaces locally, which is exactly where this agent's own
  verification steps run.
- Re-confirmed (again) the in-tree triage protocol (write real file → diff/grep → `git checkout --`
  restore) from the NA-56 lesson: 43 files flagged today (spec cited 44 at spec-time — one drifted
  out on this branch), 1 shatter reconfirmed on the plan's own pre-classified single-write pass
  (`commands/spec.md`) plus the 1 second-pass shatter this round discovered (`commands/plan.md`) —
  neither the plan's count nor its triage method is a ceiling; both explicitly say so and both were
  exercised for real this round, not just as a hypothetical caveat.
- Confirmed the RTK-masking lesson does NOT extend to script-internal `pnpm exec prettier` calls
  (only interactive shell commands typed directly appear to be rewritten by the RTK hook) — invoking
  `check-plugin-docs-format.sh` directly via `bash` produced prettier's real native
  `[warn] <file>` / `Checking formatting...` output on both the clean-pass and the corrupted-probe
  runs, not RTK's generic "All files formatted correctly" mask. Still used the raw
  `./node_modules/.bin/prettier` binary for all direct ad-hoc verification commands per the standing
  rule; only the wrapper script's own internal `pnpm exec` call was left as specified (CI has no RTK
  either way).
- The pre-commit hook (lint-staged) itself runs `prettier --write --ignore-unknown` on every staged
  file at commit time — this is the exact re-write-on-commit mechanism the whole NA-62 story defends
  against, so it is not safe to assume a clean pre-commit-hook exit means nothing regressed; verified
  after each of this story's 3 commits that the full-tree `--check` was still green and the
  quad-backtick census was still exactly 4 post-commit, not just pre-commit.

## NA-61 — PR #129 review round: unfilled `TODO —` placeholder defeated the skip-and-surface net (`plugins/sdlc/skills/writing-docs/SKILL.md`, `plugins/sdlc/refs/docs-pipeline.md`)

- **A "presence-only" guard and a "the field is now guaranteed present" story combine into a
  silent regression the moment the guaranteed-present value can itself be an unfilled
  placeholder — and this is the SAME failure shape as the NA-60 "gate on the real-signal subset,
  not the union" lesson, just one abstraction level up.** NA-61's own placeholder design (a
  `TODO —` scalar so an unfilled field is at least valid YAML) was never reconciled against the
  two guards that read it: the founder-confirm gate checks **presence**, and §19's
  skip-and-surface fires on **absence**. A `TODO —` value is present, so neither guard catches an
  unedited scaffold — worse than pre-NA-61, where the same page (missing frontmatter entirely)
  was loudly skipped. The fix pattern generalizes: whenever a story introduces a **placeholder
  value that is valid-but-meaningless**, every downstream guard that used to test
  presence/absence must be re-audited to also test **"is this the placeholder,"** not just
  "is this populated" — a placeholder is a third state the binary guard was never designed for,
  and it's very easy to design the placeholder and forget to chase its shadow through every
  consumer. I designed the placeholder (Task 1) and separately re-scoped the guards' rationale
  prose (Task 2) in the same PR without ever asking "what if seed confirms the scaffold
  unedited" — the two tasks were sequenced correctly per the plan but never cross-examined
  against each other from the guard's point of view.
- **A reviewer's own suggested replacement text can itself reintroduce a documented YAML hazard
  from this same file's history — verify a suggested fix against known landmines before adopting
  it verbatim.** Finding 2 suggested `TODO: one line …` as the em-dash-free placeholder
  replacement; a colon immediately followed by a space **inside** an unquoted plain scalar is the
  exact "mapping values are not allowed here" YAML break this file's own NA-58 memory entry
  already documents (a URL followed by `: ` broke a skill description the same way). Used
  `TODO(fill)` instead — no colon, no em-dash, YAML-safe, and validated with
  `python3 -c "import yaml; yaml.safe_load(...)"` before committing, not just eyeballed.
- **Prettier canonicalizes a code span with a leading/trailing space (`` ` — ` ``) down to the
  CommonMark-equivalent trimmed form (`` `—` ``) on `--write`**, breaking a prose sentence whose
  meaning specifically depended on the surrounding spaces being visually present inside the span
  (I was trying to say "the exact `—` sequence," not just "an em-dash"). This is a **new**
  variant of the "prettier silently normalizes markdown you didn't expect" family (NA-27/NA-51
  entries document bare-`*`-escaping and code-span-line-break variants) — caught by the
  idempotency diff, not by `--check`, since my own hand-written first draft already "looked"
  formatted. Fix: don't rely on a code span's internal whitespace to carry meaning; say "a space,
  an em-dash, and a space" in prose instead of `` ` — ` ``.
- Extending a guard's trigger condition (missing → missing-OR-unfilled) that has **already been
  adopted verbatim by a second consumer** (audit's §21 says "§19's, verbatim") means the second
  consumer's own restating sentence must be re-touched too, even though its own logic didn't
  change — only its **description** of what it adopted did. Missed this on the first pass of the
  fix, caught it by grep. General check: after widening a rule at its single source-of-truth
  section, grep the whole file for every other section that describes itself as adopting that
  rule "verbatim" and confirm each one's own restating prose still matches the widened condition
  word-for-word, not just in spirit.
- The review's suggestion "file a follow-up story, or note it as an OQ — your call" for the
  genuinely-out-of-scope half of finding 2 (robustly fixing §8's positional `" — "`-delimited
  format) was resolved as an in-repo Open Question blockquote at the point of use (§8 itself),
  matching this file's own pre-existing `> **Underspecified — decision recorded (Open
Question #1, adopted).**` convention — cheaper and more discoverable than a new Jira ticket for
  a plugin-internal design note with no assigned owner or timeline yet.

## NA-61 — writing-docs templates emit title/description/related-adrs frontmatter (`plugins/sdlc/skills/writing-docs/SKILL.md`, `plugins/sdlc/refs/docs-pipeline.md`, `plugins/sdlc/.claude-plugin/plugin.json`)

- **A hand-wrapped checklist bullet that matches the FILE's own established wrapping
  convention still breaks the PLAN's own single-physical-line verification grep — and the
  right fix is to verify with the flattened `tr` idiom, not to un-wrap the line.** The plan's
  Step 5 gave the new Self-Review line as one long logical sentence; I typed it wrapped across
  two physical lines at the same point every neighboring long checklist bullet in this exact
  file already wraps (`Voice and output format were resolved from…`, `If this is an explanation
page…`) — genuinely the more consistent choice, and Prettier's `proseWrap: preserve` will
  never rejoin it. But the plan's literal verification command
  (`grep -c 'no .TODO —. placeholder left'`) assumed one physical line and returned 0 on a
  clean pass. This is the established "grep trap" class (NA-53/54/55 memory entries) applied to
  a bullet I wrapped myself, not one Prettier wrapped — confirmed correct with
  `tr '\n' ' ' | tr -s ' ' | grep -o '...'` instead of relaxing my formatting to chase the
  literal grep. Lesson: when a plan's own verbatim-text grep is single-line but the insertion
  point sits inside prose this repo already wraps by convention, match the file's convention
  and re-verify with the flatten idiom — don't treat "the plan's grep failed" as license to
  make the source uglier just to pass a check.
- **A trailing prose paragraph directly followed (zero blank lines) by a new list bullet is
  Prettier-non-idempotent even when neither is itself indented/nested — this is a NEW distinct
  landmine flavor from the already-documented "2-space-indented fence under a list item" one.**
  Adding the `related-adrs:` reliability-caveat paragraph immediately above the pre-existing
  `- **Dangling code reference.**` bullet (no blank line between, matching how the OLD one-line
  caveat sentence had sat right above it) produced a real `prettier --write` diff on the FIRST
  pass: Prettier inserted a blank line between the paragraph and the bullet to make the list
  boundary unambiguous. Caught only by the copy → `--write` → `diff` idempotency protocol
  (a bare `--check` also would have caught it here, but the copy protocol is what's mandated and
  what I ran). Fix: always put a blank line between a freestanding paragraph and a list that
  follows it, even if the paragraph it's replacing didn't have one — a longer multi-line
  replacement paragraph changes Prettier's parse of the paragraph/list boundary even when a
  shorter one-liner in the same spot didn't trigger a rewrite.
- **The plan's own frontmatter-untouched verification grep
  (`git diff SKILL.md | grep -E '^[-+](name|description):' | wc -l`, expected 0) is imprecise
  and produces a false-positive the moment the story's OWN body edits add new
  `description:`-prefixed lines** — it can't distinguish SKILL.md's real YAML frontmatter
  (lines 1–4) from the four new body-template `description: TODO — …` lines this story
  legitimately adds, so it returned 4, not the plan's expected 0. Verified the actual invariant
  (frontmatter untouched) correctly instead via `diff <(git show HEAD:<file> | sed -n '1,4p')
<(sed -n '1,4p' <file>)` → `UNCHANGED`. Lesson: when a plan's "prove X untouched" grep pattern
  is a substring that the SAME diff's legitimate new content can also match, don't trust the
  grep's raw count — isolate the specific line range the invariant actually claims and diff
  that range directly.
- Re-confirmed the NA-51 scratch-copy lesson on two separate files this round (SKILL.md and
  docs-pipeline.md): a scratch copy must be a `.md`-suffixed file **inside the repo tree**
  (sibling to the real file, not `/tmp` or the session scratchpad) for `prettier --file-info`
  to report `ignored: false` + a non-null `inferredParser` — otherwise `--write` silently
  no-ops and the "IDEMPOTENT" result is a false negative with zero signal value. Always run
  `--file-info` on the scratch path first and confirm both fields before trusting the diff.
- Confirmed (again, now 6th time across NA-54/55/57/58/60/61) that
  `pnpm nx affected -t test --base=remotes/origin/develop` and `pnpm nx format:check` both
  report clean/no-tasks for a `plugins/sdlc/**`-only change in this repo — expected, not a
  skipped gate.

## NA-60 — PR #127 review fix: trigger the warning on `LIKELY_KEYS`, not `OUT_OF_SCOPE`

- **A "fires iff `SUPERSET ≠ ∅`" gate is wrong the moment the superset legitimately contains a
  demoted-but-still-counted subset** — the original design computed `OUT_OF_SCOPE = LIKELY_KEYS ∪
STANDARDS_MATCHES` and then gated the warning-no-op split and the confirm-gate print on
  `OUT_OF_SCOPE ≠ ∅`, which is true whenever _either_ subset is non-empty. That silently let a range
  whose only out-of-scope tokens were standards-prefixed (`RFC-2119`, `SHA-256`, zero real missing
  stories) fire a warning with an **empty** `LIKELY_KEYS` individual list under an active header and
  an action-demanding footer — driven entirely by tokens the same design explicitly meant to
  _demote_. The general lesson: whenever a "fires iff X ≠ ∅" condition is defined over a union set
  that itself splits into a "real signal" part and a "demoted noise" part, the gate belongs on the
  **real-signal subset alone**, never the union — a union-gated trigger silently promotes the
  demoted part back into a trigger the moment it's the only thing present, defeating the demotion.
  This was caught by review, not by any of my own verification greps in the original round, because
  every grep I wrote checked that the _pieces_ were present and worded correctly — none checked
  whether the pieces _combined_ correctly for the all-standards, zero-likely-keys case, since I
  never constructed that specific state by hand while verifying. Lesson: for a multi-set overlay
  spec, explicitly hand-walk each of the state model's named states (not just each spec clause) and
  confirm the file's own gate conditions actually route that state where the state model says it
  should — grepping for presence of the right words is not the same check.
- **A "narrow the old rows to the same trigger variable" fix for an overlapping-rows finding
  (reviewer's finding 3) came for free once the root-cause variable was corrected** — once the
  no-op split's trigger changed from `OUT_OF_SCOPE ≠ ∅` to `LIKELY_KEYS ≠ ∅`, the pre-existing
  "no stories merged" clean-no-op rows and the new warning-no-op row became keyed off the same
  single boolean (`LIKELY_KEYS` empty vs. non-empty) and were therefore automatically mutually
  exclusive — no separate precedence rule was needed. When two rows' overlap traces back to a
  shared root-cause variable being wrong in one of them, fixing the root variable can resolve the
  overlap finding as a side effect; always re-check whether a downstream "add precedence" finding is
  still needed after the root fix, rather than fixing both independently and risking a
  now-redundant precedence clause that contradicts the corrected trigger.
- **A "no example-parsing hazard because init never writes a stub" claim can go stale the instant a
  _different_ file (not the one init writes) carries a copyable example** — my original resolver
  robustness note reasoned correctly about the manifest init writes, but `docs-manifest-template.md`
  itself (a separate ref file, always present in the plugin, sometimes copy-pasted by a founder
  looking at the shape) carries its own illustrative `<... e.g.: ET>` text. Fixed by extending the
  resolver's tolerant-parsing rule to also strip `<...>`-bracketed spans (generalizes past the
  comment-only case), rather than editing the template's example to be non-key-shaped — the
  resolver fix is strictly more robust since it protects against _any_ future template wording, not
  just today's `ET` example.
- Re-confirmed the in-repo (not `/tmp`, `.md`-suffixed) scratch-copy idempotency protocol from
  earlier this same session on all three re-touched files — held stable on every file, first pass.

## NA-60 — Make release-mode PROJECT_KEYS discoverable (`plugins/sdlc/refs/docs-pipeline.md`, `plugins/sdlc/commands/docs.md`, `plugins/sdlc/refs/docs-manifest-template.md`, `plugins/sdlc/commands/init.md`, `plugins/sdlc/.claude-plugin/plugin.json`)

- **`prettier --file-info` reporting `ignored: false` is necessary but not sufficient to trust an
  idempotency-check scratch copy — the copy also needs a filename `prettier` actually infers a
  parser for.** A first attempt copied `docs-pipeline.md` to a non-`.md`-suffixed scratch name
  (`docs-pipeline.md.na60scratch`); `--file-info` reported `ignored: false` (looked safe per the
  NA-51 lesson) but `inferredParser: null` — `--write` silently no-op'd on it, so a `diff` against
  the original trivially showed "IDEMPOTENT" with zero signal value, identical in effect to the
  known `ignored: true` false-negative this check exists to catch. Fix: always check **both** fields
  of `--file-info` (`ignored: false` **and** `inferredParser` non-null) before trusting a diff
  result, and keep the scratch copy's own extension (`.md`) rather than appending a suffix.
- **A plan's own hand-typed markdown table content can be Prettier-non-idempotent on the very first
  `--write` even though the plan author clearly intended it to be final text** — my initial edit
  reproduced the plan's five-row `OUT_OF_SCOPE`/`IN_SCOPE`/etc. set-definition table verbatim
  (including its exact column-padding spaces), and `prettier --write` still re-padded three of the
  five rows on first pass (unrelated to content, purely because the em-dash/prefix cell widths I
  typed didn't match Prettier's own column-width computation for the finished file). This is not a
  defect in the plan — table cell padding is never meant to be typed by hand; the fix is simply to
  run `prettier --write` on the real file immediately after any table edit and treat its output as
  authoritative, then re-verify idempotency from that written state, rather than trying to
  hand-match Prettier's padding or treating the first `--write` diff as evidence of a problem.
- **A NA-62-landmine-avoidance fenced block that sits under a numbered list item can require its
  _surrounding bullets_ to also drop to column 0, not just the fence itself, when the source plan
  says so** — Task 2 Step 1's fenced text block (the warning-message template) was specified by the
  plan sitting between two column-0 (undented) bullet groups, deliberately breaking out of list item
  3's normal 3-space-indented continuation. My first draft kept the post-fence bullets indented 3
  spaces (matching the pre-fence sub-bullets' style, which felt more consistent) — a deviation from
  the plan's literal text that would have been my own choice, not a required fix, but I caught it by
  diffing my draft against the plan's exact characters before running Prettier, and re-indented to
  match column 0 exactly, since the plan's authors had presumably already reasoned through the
  NA-62 dedent boundary for that specific insertion point. Lesson: when a plan hands you literal
  markdown to insert (not just a description of what to add), match its whitespace exactly on the
  first pass rather than reflowing it to look more consistent with neighboring prose — the literal
  text may already encode a landmine-avoidance decision that isn't otherwise explained.
- Re-confirmed the NA-55/NA-52 lesson that `pnpm nx affected -t test --base=remotes/origin/develop`
  and `pnpm nx format:check` both report clean/no-tasks for a `plugins/sdlc/**`-only change — not a
  skipped gate, the expected result for this plugin's Nx-project-less path.
- This story's dispatch prompt explicitly overrode the standing "domain agent never pushes" handoff
  rule (`domain-agent-handoff.md`'s "Do NOT push") with an explicit instruction to push
  `feat/NA-60` and verify `git rev-parse HEAD == git rev-parse origin/feat/NA-60` myself, since no
  Principal Engineer orchestrator was dispatching this run (a direct, already-planned single-agent
  story with no PR to raise). Confirmed the override is legitimate per this agent's own contract
  (a message from the dispatching agent directs the work); did not raise a PR or run
  session-complete, per the same prompt's explicit "no PR, no session-complete" instruction.

## NA-57 — PR #125 review round (`plugins/sdlc/commands/docs.md`, `plugins/sdlc/refs/adr-pipeline.md`)

- **An unqualified "manifest absent → silent no-op" error-table row that sits ABOVE mode-specific
  rows in the same table can silently re-swallow a route this same story just made manifest-exempt
  — even though every other closing check (grep-A, grep-B, guard-presence, Prettier idempotency)
  passed clean.** `commands/docs.md`'s error table's first row read
  `.claude/project/docs-manifest.md absent → Silent no-op` with **no mode qualifier** — a leftover
  from when all four generic modes shared one manifest gate. Once `seed adr`/`distill` became live,
  **manifest-exempt** routes, that same unqualified row is the first "manifest absent" match a
  reader (or a future implementer deriving behavior from this table) would apply to them too —
  reintroducing exactly the "collapse a distinct path into a benign no-op" defect class the whole
  NA-50 epic was about closing, in the very last PR. `audit` had already been given its own scoped
  row (a precedent this row should have matched from the start). None of NA-57's own verification
  greps (grep-A `/sdlc:adr`, grep-B stub phrases, guard-presence strings) could catch this — it's a
  **semantic scope gap in unchanged pre-existing prose**, not a residual string. Lesson: when a
  story adds a new manifest-EXEMPT route next to existing manifest-GATED ones, always re-read every
  unqualified/table-wide error row for accidental scope creep onto the new exemption — a clean grep
  sweep proves no _string_ went stale, not that no _prose scope_ did.
- **A command removal's migration path is only "clean" (AC4) if the successor surface is
  discoverable from the STOP/usage messages a confused caller actually hits** — not just from full
  documentation a founder may not read. `seed adr` was structurally correct (special route, live,
  all guards relocated) but invisible at the two places someone migrating off deleted `/sdlc:adr`
  would actually look: the usage string (`seed <type> [topic]` doesn't surface `adr` — it's
  deliberately excluded from `SEED_TYPES`) and the unknown-seed-type STOP message (enumerates only
  `SEED_TYPES`, silent about the special route that isn't a member). Fixed by adding `seed adr
"<pattern>"` as its own clause in the usage string (echoed on every STOP that prints it) and a
  one-line "for ADRs, use seed adr ..." pointer inside the unknown-type STOP's own fenced message.
  Generalizable check for any future "type X is deliberately excluded from the generic enum"
  design: grep every STOP/usage message that enumerates the _generic_ set and confirm the excluded
  special case is named as a sibling invocation form, not just documented in prose elsewhere.
- **A section can accurately be named "command-layer" for one reason (where the founder-confirm
  gate lives) while its own body prose overclaims a SECOND, unrelated thing (who executes the
  branch/PR naming stated in the same section) is also command-layer-only — and the two claims are
  easy to conflate because they share a heading.** `refs/adr-pipeline.md` §3a is genuinely
  command-layer for the gate (correct, established in §2/§3). But its own intro sentence ("this
  section adds only what is genuinely command-layer-only: branch/PR naming and the post-PR
  control-flow tail") extended that framing to branch/PR naming too — false: `knowledge-engineer.md`
  actually **creates** the branch and **raises** the PR per that convention (its own branch/commit/
  return steps say so explicitly). Fix: state the naming convention as single-sourced in the ref
  (true) with the **agent** as its executor (also true), and keep only the post-PR control-flow tail
  (loop-driving after the agent's dispatch returns) as the thing that's actually command-layer.
  When a section heading names ONE property (e.g. "where the gate lives"), audit every sentence in
  the section body for a second, unstated property riding along on the same label — a reviewer
  reading only the heading (not the cross-referenced agent file) has no way to catch the overclaim.
- Re-verified the NA-62 in-tree copy → `--write` → `diff` idempotency protocol on the two files this
  round touched (`docs.md`, `adr-pipeline.md`) — both stable on the first pass; no new
  list-nested-fence hazard introduced by these three fixes (finding 2's fenced-block edit reused the
  fence's pre-existing, already-stable indentation rather than reintroducing a dedent).

## NA-57 — Absorb /sdlc:adr into /sdlc:docs, full command removal (`plugins/sdlc/commands/docs.md`, `plugins/sdlc/commands/adr.md` [deleted], `plugins/sdlc/refs/adr-pipeline.md`, `plugins/sdlc/refs/docs-pipeline.md`, `plugins/sdlc/refs/doc-types.md`, `plugins/sdlc/agents/knowledge-engineer.md`, `plugins/sdlc/agents/qa-engineer.md`, `plugins/sdlc/refs/analyze-protocol.md`, `plugins/sdlc/commands/analyze.md`, `plugins/sdlc/refs/qa-engineer-playbook.md`, `plugins/sdlc/skills/writing-adrs/SKILL.md`, `plugins/sdlc/README.md`, `plugins/sdlc/.claude-plugin/plugin.json`)

- **A spec's own two-grep-family derivation methodology (grep-A command-name string, grep-B
  stub/deferral phrases) can still be structurally blind to a third residue category: bare
  file-path mentions of the deleted file that carry neither shape.** After all 6 named Task 6
  files passed grep-A clean, a repo-wide `grep -rn 'commands/adr\.md' plugins/sdlc/` (not in the
  plan/spec's own closing-check command list) found **6 more** dangling "Mirror `commands/adr.md`"
  / "mirrors `commands/adr.md`'s ... shape" references inside `refs/docs-pipeline.md`'s
  sync/release/seed/audit branch-naming and control-flow tables — precedent-mirroring prose written
  when `/sdlc:adr` was still live, describing how the _other_ modes' branch/control-flow
  conventions echo the ADR command's. None contain the string `/sdlc:adr` (so grep-A misses them)
  and none match any grep-B phrase (`deferred to NA-57`, `not yet implemented`, `use seed mode`,
  `NA-57`) — they're a genuinely distinct shape neither derivation family targets: a bare relative
  path to a file this same story deletes. **Whenever a story deletes a file that other prose in the
  same plugin used as a "mirrors X" / "see X" precedent-citation anchor, grep the whole plugin tree
  for the literal file path itself** (not just the command-invocation string), separately from
  whatever the spec's own named grep families are — a "the spec's greps are the authoritative
  closing check" instruction does not mean the spec's greps are complete; verify their coverage by
  construction (what shape of reference _could_ survive a deletion?) rather than trusting the named
  list exhausts it. Fixed with a 7th commit (`fix(sdlc): ...`) after the planned 8-task sequence,
  citing the gap explicitly rather than silently folding it into Task 5's or Task 8's commit.
- **Dedenting a fenced code block under a list item to column 0 (the NA-62 landmine fix) can leave
  the _next_ paragraph in the same list-item continuation still indented — and that mismatch, not
  the fence itself, is what breaks Prettier idempotency.** `adr-pipeline.md` §5's halt-message fence
  sat under `- **Tools absent → halt.**`, with a trailing sentence ("It does not silently proceed
  without them.") indented 2 spaces _after_ the fence, as continued list-item prose. Dedenting only
  the fence to column 0 (per the established NA-62 fix pattern) produced a **first**-`--write`-pass
  diff a naive `--check`-only verification would have missed: Prettier reflowed the _trailing_
  paragraph's indentation to match the fence's new (list-broken) context, since the column-0 fence
  terminates the list continuation and the paragraph after it is no longer "inside" the list item
  from Prettier's parser's point of view. Caught only by the in-tree copy → `--write` → `diff`
  idempotency protocol (never a bare `--check` PASS) — confirmed via `prettier --file-info` that the
  copy was `ignored: false` first, per the NA-51 lesson about scratch copies outside the repo tree
  silently no-op'ing `--write`. Fix: dedent the _following_ prose to column 0 too, not just the
  fence — verify the **whole** list-item's remaining continuation lines after any fence dedent, not
  just the fence's own indentation.
- **A `find-skills`/`skill-creator` step was not applicable this story** — pure command-absorption
  editing an existing surface, no new capability gap and no candidate skill to scaffold. Both loaded
  per the required-first-turn-skills gate; neither was invoked toward a scan/gap-fill action, which
  is a legitimate no-op for a plugin-authoring story with no drift-scan component.
- Confirmed (again) `pnpm nx affected -t test --base=remotes/origin/develop` reports "No tasks were
  run" for a `plugins/sdlc/**`-only change — expected, not a skipped gate, matching every prior
  plugin-authoring story this session.
- **A plain `pnpm exec prettier --check <file>` in this environment (RTK/rtk hook wrapper active)
  printed a misleadingly generic "All files formatted correctly" message while still exiting 1** —
  the wrapper's filtered/summarized output did not match its own exit code. `rtk proxy pnpm exec
prettier --check <file>` (bypassing the hook's rewrite) gave the real, actionable
  `[warn] Code style issues found` output. When a wrapped command's stdout and exit code visibly
  disagree, reach for the raw/proxy form immediately rather than debugging the mismatch — it's a
  wrapper artifact, not a signal about the file.
- This repo's agent-file frontmatter `description` field for `knowledge-engineer.md` was already
  1216 chars pre-story (confirmed via `git show HEAD:<file>` before editing) — well over the
  1024-char cap that's real and enforced for **command** frontmatter but an unenforced carryover for
  **agent** files (per the NA-55 memory entry below). Grew it slightly to 1254 mid-edit, then
  trimmed the final "Triggered manually via..." clause back down to 1199 — net **improvement** over
  the pre-existing baseline, not a new violation, but flagged in the PR return per the established
  "don't chase a pre-existing unenforced overage silently" convention.

## NA-55 — `/sdlc:docs audit [--dry-run]` mode implementation (`plugins/sdlc/commands/docs.md`, `plugins/sdlc/refs/docs-pipeline.md`, `plugins/sdlc/refs/doc-types.md`, `plugins/sdlc/agents/knowledge-engineer.md`, `plugins/sdlc/.claude-plugin/plugin.json`)

- **A plan's own gate-anchor pointer-count expectation can go stale the moment the story's own new
  content legitimately adds MORE pointers to the thing it's renaming.** NA-55's Task 1 Step 7 and
  Task 6 Step 4 both hard-coded "7 pointers total" / "8 total (1 heading + 4 pipeline + 3 docs.md)"
  for the renamed manifest-gate anchor — correct for the pre-existing sync/release/seed pointers,
  but the plan's own Task 2 (§20/§24) and Task 3 (the audit behavioural contract) each **correctly**
  add their own new pointer to the same shared gate, since `audit` genuinely needs to cite it from
  inside its own contract sections too (exactly the "point at it, don't re-derive it" rule the plan
  itself states). Actual final count: **10** pointer occurrences (6 in `docs-pipeline.md`, 4 in
  `docs.md`) + 1 heading — not the plan's 7/8. Verified each of the 3 "extra" sites individually: all
  are legitimate citations, none re-derive the gate. When a rename-and-repoint task's own plan gives
  an exact expected grep count, and a _later task in the same plan_ adds new prose that necessarily
  cites the renamed anchor again, recompute the count by hand rather than trusting the earlier task's
  frozen number — the discrepancy is a sign of correct-and-expected growth, not a bug, but it will
  fail the plan's own literal "Expected: N" assertion if followed blindly.
- **A verification grep built from disjunctive stub-language alternatives can true-positive on the
  wrong reason.** Task 6 Step 2's `grep -rn 'audit.*not yet implemented\|audit|distill land\|audit`/`distill`'` intends to catch a surviving "audit is not yet implemented" stub claim, but its third alternative
(`` `audit`/`distill` ``, a fixed backtick-slash-backtick substring) also matches the **legitimate**
first-token enumeration line ("not one of `sync`/`release`/`seed`/`audit`/`distill`") — that line is
correct and unrelated to the stub-claim the check exists to catch (`audit` genuinely IS a
recognised first token; only the future-mode *stub set* dropped it). Confirmed with a narrower,
intent-scoped grep (`audit.*not yet implemented`, `` `audit`/`distill` `` — the literal old
  step-3 stub phrase) that zero genuine stale claims survive. When a plan's own multi-alternative
  verification grep fires, check which alternative matched and whether that alternative's *intent\*
  (not just its literal string) actually applies to the hit before treating it as a failure.
- **This repo's agent-file frontmatter `description` fields are not actually bounded at 1024 chars
  in practice, despite the plan/spec importing that limit from the command-frontmatter rule.**
  `agents/knowledge-engineer.md`'s description was already 1063 chars (over the stated 1024 cap)
  **before** this story touched it — confirmed via `git show HEAD:<file>` on the pre-NA-55 commit —
  and no script in `plugins/sdlc/scripts/` validates agent-description length (only
  `skill-creator/scripts/quick_validate.py`, which is `SKILL.md`-only and explicitly refuses any
  other filename). The 1024 cap is real for **command** frontmatter (`docs.md`'s own description had
  to be trimmed twice this story to fit) but the plan's "Keep the block ... ≤ 1024 chars" instruction
  for the **agent** file's description clause is an unenforced carryover, not a live constraint.
  Trimmed the new audit clause for cleanliness anyway (1259 → 1216 chars) but did not chase the
  baseline's own pre-existing overage — flag this in the story return rather than silently absorbing
  it as a new bug to fix, since fixing a pre-existing, unrelated overage is out of this story's scope.
- Confirmed (again, third time after NA-53/NA-54) that `pnpm nx affected -t test --base=remotes/origin/develop`
  reports `No tasks were run` for a `plugins/sdlc/**`-only change — expected, not a skipped gate.
- `pnpm nx format:check` (full-repo) is a cheap, silent-on-success final sweep distinct from the
  per-file `prettier --check` used mid-task — run it once at the very end of a multi-file plugin
  story to catch any incidental reformat prettier's pre-commit hook didn't already normalize.

## NA-54 — `/sdlc:docs seed` mode implementation (`plugins/sdlc/commands/docs.md`, `plugins/sdlc/refs/docs-pipeline.md`, `plugins/sdlc/refs/doc-types.md`, `plugins/sdlc/agents/knowledge-engineer.md`)

- **A plan's own literal verification grep can fail to match the plan's own verbatim template
  text, with no line-wrap involved at all** — a genuinely new variant of the "grep trap" family.
  NA-54's Task 3 Step 8 asserted `grep -c "docs-pipeline.md\` \*\*§§15–19\*\*"`, expecting the
behavioural-contract section's pointer sentence to have those two tokens adjacent. But the same
plan's own Step 5 dictated the sentence verbatim as "...lives in
`${CLAUDE_PLUGIN_ROOT}/refs/docs-pipeline.md`§2, and the seed-specific procedure — ... — is
defined once in that ref's **§§15–19**." — a full independent clause sits between the two tokens,
so the assertion cannot pass no matter how faithfully the template text is transcribed. Confirmed
by grepping the finished file for`§§15` alone: exactly one hit, at the correct location, just not
  in the shape the assertion demanded. When a plan's own dictated prose and its own verification grep
  disagree like this, trust the dictated prose (it's the spec-derived content) and flag the grep as
  wrong, rather than rewriting mandated verbatim text to chase a miswritten check.
- **When a plan adds an Nth branch to an agent file that already enumerates "N-1 of something" in
  more than one place, the plan may name only the most prominent occurrence for you to fix, and miss
  siblings.** NA-54's plan explicitly called out "All three dispatch types" → "All four" in the
  Required-skills preamble, but the same file separately said "You run one of three pipelines" (the
  `## Pipeline` intro bullet list) and "in any of the three [pipelines]" (the phase-boundary note
  after the release Phase-1/2 summary) — neither named by the plan, both genuinely stale once a
  fourth dispatch branch existed, and both the exact "NA-53 shipped 'seed'/'audit'/'distill' stale in
  three places, plan named two" defect shape from this file's own NA-52 entry above. Fixed both for
  consistency and noted the deviation from the plan's literal step list in the PR return — grep the
  whole file for the literal word "three" (or whatever cardinal the pre-change state used) before
  considering an Nth-branch addition complete, don't rely on the plan enumerating every site.
- **`plugins/sdlc/.claude-plugin/plugin.json`'s "every commit shipping new content bumps the
  version" convention (stated as a hard rule in this same file's NA-58 entry below: "every prior
  commit shipping new content under `plugins/sdlc/` bumps `plugin.json`'s version in the same
  commit … pinned consumers won't see the new skill or the agent's updated instructions otherwise")
  was silently NOT followed by NA-53** (`git show <every NA-53 commit> --stat | grep plugin.json` →
  no hits across all of NA-53's commits, despite NA-53 shipping a full new release-mode dispatch
  branch) — confirmed via `git log -p --follow -- plugins/sdlc/.claude-plugin/plugin.json`, which
  showed the version frozen at `0.36.0` since NA-52's last commit. **My first-round mistake:** I
  read that unbumped gap as a "more recent precedent" and deliberately matched it (no bump for
  NA-54 either), reasoning that resurrecting an unfollowed convention unilaterally would itself be
  an inconsistency. **That reasoning was wrong** — a documented hard rule that one sibling story
  silently skipped is a **known gap in that story**, not a new counter-rule superseding the
  original. NA-54 ships a whole new `seed` mode (unambiguously new content, exactly the case the
  rule was written for); a consumer pinned at `0.36.0` would silently never receive it. Fixed:
  bumped `0.36.0` → `0.37.0` (minor — new backward-compatible feature) in the same PR round this
  memory correction landed in. **Lesson for any future story that finds a documented hard rule
  unfollowed by a recent sibling:** the rule wins; treat the sibling's gap as a defect to flag
  (and, ideally, backfill), never as a new precedent to extend. Silently matching an unfollowed
  rule compounds the drift instead of surfacing it.
- The `tr '\n' ' ' | tr -s ' '` (flatten-and-squeeze) idiom the plan mandated for every prose-spanning
  verification grep held up in practice across all of Tasks 2/4/5 — every squeezed assertion matched
  on the first attempt; the plain `tr '\n' ' '` trap the plan warned about (indented continuation
  lines flattening to a double space) was never hit because the squeeze was applied unconditionally
  from the start, per the plan's own "do not add a multi-word grep over prose without both" rule.
- Confirmed `pnpm nx affected -t test --base=remotes/origin/develop` reports "No tasks were run" for
  a plugin-authoring-only change under `plugins/sdlc/**` (no Nx project owns that path) — this is the
  expected, correct result for a docs/instructions-only story, not a sign the gate didn't run; don't
  mistake a clean "no tasks" affected-scoped result for a skipped quality gate.

## NA-52 — PR #115 review round 3, 10 accepted findings (`plugins/sdlc/refs/docs-pipeline.md`, `plugins/sdlc/refs/doc-types.md`, `plugins/sdlc/commands/docs.md`, `plugins/sdlc/agents/knowledge-engineer.md`, `docs/superpowers/plans/NA-52.md`)

- **A load/list asymmetry (skill loaded unconditionally but the `Skills loaded:` return contract
  lists it conditionally) is fixable two ways, and the deciding factor is which condition is
  cheaper to state precisely, not which file "feels" like the source of truth.** Here the fix was
  to make the _load_ conditional (only in Phase 1, only once affected `how-to` rows are resolved)
  to match the already-conditional _return_ line, rather than the other way around — because the
  return condition ("a narrative draft was actually produced") was already correct and
  well-motivated (Phase 2 genuinely never drafts), so loosening it to "unconditional" would have
  been the wrong direction. When a review finds this shape of asymmetry, check which side already
  states a correct, well-reasoned condition before picking which side to change.
- **`plugins/sdlc/scripts/check-agent-skill-preloads.sh` only enforces two structural things — no
  frontmatter `skills:` key, and one verbatim marker sentence present somewhere in the file — it
  does NOT enforce the shape (branched vs. merged) of an agent's "Required skills" prose.** This
  means a "merge 4 restatements of a shared skill list into one canonical statement referenced by
  the return contract" simplification (the kind finding #10 asked for) is always safe to attempt
  from the gate's perspective; the actual risk is losing information (e.g. quietly dropping the
  distinction between an unconditional skill and a conditionally-loaded one), not tripping the
  gate. Read the gate script itself before assuming a required-skills restructuring needs a
  "skip and report not-applied" fallback — it's a much narrower contract than the prose describing
  it might suggest.
- **A "single source of truth cell, others reference it" fix for a literal string duplicated across
  files (finding #9) needs the _registry's own self-check section_ to explicitly bless the
  in-file duplication it still permits (schema-table example mirroring the registry row), or the
  next reviewer will re-flag the schema-table copy as a 6th restatement site.** Added an explicit
  self-check bullet naming both in-file locations as the sanctioned mirror and every other file as
  reference-only — this is the same "precedence rule stated in the guard itself, not just in
  prose above it" pattern from the NA-51 round-2 memory entry, applied to a duplication guard
  instead of a gating guard.
- **A stale "no such command exists yet" claim and a stale "seven sections" count are the same
  bug shape appearing twice in one PR (doc-types.md's registry intro, the plan's Task 4/AC-coverage
  references) — once a file ships the thing a sibling doc said didn't exist yet, or a section count
  changes, grep the WHOLE repo for the old claim/number, not just the line(s) the review named.**
  Found and fixed a 4th, unflagged occurrence of "seven sections" (the plan's own `Self-review`
  AC-coverage line) this way — the review only named 3 of the 4 stale references to the same
  underlying drift.
- Confirmed `pnpm prettier`/`pnpm exec prettier`/`pnpm nx` all require `node_modules` to actually
  exist in this repo checkout — a fresh worktree or a checkout that never ran `pnpm install` has
  none, and `pnpm exec prettier` fails with `ERR_PNPM_RECURSIVE_EXEC_FIRST_FAIL` (looks like a
  missing-binary error, not a missing-install one) rather than a clearer "run install first"
  message. `pnpm install --frozen-lockfile` before the first `prettier`/`nx` invocation in any
  fresh checkout is cheap insurance against mis-reading that error as something else.

## NA-51 — PR #113 review round 2, 10 accepted findings (`plugins/sdlc/commands/init.md`, `plugins/sdlc/refs/doc-types.md`, `plugins/sdlc/refs/docs-manifest-template.md`)

- **A "gate a new write step on opt-in acceptance" design is incomplete without an explicit
  precedence rule for the case where the gated artifact already exists but this run's answer was
  Skip (or never asked).** Round 1's fix stated the 4g gate as "accepted this run OR artifact
  already exists" but never said which wins when a manifest exists AND this run's answer is Skip —
  QA correctly read that as a live contradiction (Skip's own description said "writes nothing").
  The fix is a one-sentence precedence rule stated in at least three places that must all agree:
  the opt-in's own `Skip` bullet, the write-step's own header, and the error/no-op table's first
  row — "an existing artifact always reaches the merge step regardless of this run's answer; Skip
  only means don't create one." Any time a review finds a same-file contradiction between two
  "correct in isolation" bullets, look for the missing precedence rule between them rather than
  patching either bullet alone.
- **A prompt that "participates in Step 0's Merge-new-findings schema-backfill loop" is a false
  claim unless the field is actually a token that loop's own diff step iterates over.** The loop
  (Step 0 → Merge new findings → step 2) explicitly diffs against
  `refs/project-context-template.md`'s token/section set — a prompt whose write target is a
  **different file** (here, `.claude/project/docs-manifest.md`, never `project-context.md`) is
  structurally invisible to that loop no matter how the prose describes it. The only fix that
  actually closes the reachability gap is a **new, explicit numbered step** in the Merge flow that
  checks the artifact's existence directly and re-asks the exact same `AskUserQuestion` — a
  cross-reference/description change alone ("this participates like any other field") cannot make
  an unreachable branch reachable. When a spec/plan or a fix instruction says a Step-3 confirm
  "participates in the merge loop," verify mechanically: does the loop's own diff step actually
  enumerate this field, or does it only enumerate `project-context-template.md` tokens? If the
  latter, the field needs its own explicit step, not descriptive prose.
- **Claiming persistence for a decision with no actual storage location is an "undecidable claim"
  bug, not a wording nit** — round 1's "Re-init semantics" bullet said a repo is "prompted once when
  merging" and called it "non-declined," implying some decline state is tracked, when nothing in
  the design persists a decline of the _opt-in itself_ (only per-row declines inside an _already-
  existing_ manifest are persisted, via the `<!-- declined: <type> -->` comment convention — a
  genuinely different, correctly-designed mechanism that must NOT be touched when fixing this).
  Before writing "prompted once" / "already declined" / any other claim implying persisted memory
  of a past answer, verify a concrete field, file, or comment convention actually stores that
  answer between runs — if none exists, the true behavior is "re-asked every time the precondition
  still holds," not "asked once."
- Restoring a bare glob (`.claude/.*-plugin-root`) that a nested ` ```markdown ``` ` fenced code
  block's own prettier "embedded language formatting" had escaped to `.claude/.\*-plugin-root`:
  wrapping the glob in a backtick code span (`` `.claude/.*-plugin-root` `` ) inside that nested
  fence is what actually survives — prettier's embedded-markdown formatter escapes bare `*` in
  prose text (emphasis-ambiguity) but never touches the contents of an inline code span, even one
  written inside an outer fenced block. Verified stable across two `prettier --write` passes.
- **A paragraph indented 6 spaces where its sibling paragraphs (same nesting level, same parent
  bullet) sit at 2 spaces renders as an indented code block**, not as continued list-item prose —
  CommonMark treats 4+ spaces of indentation beyond the container's own content column as a code
  block trigger. This is a silent, unflagged-by-prettier defect (proseWrap: preserve doesn't touch
  indentation, and prettier does not reformat indentation levels within nested list content) — the
  only way to catch it is to eyeball-compare a paragraph's leading whitespace against its true
  siblings' whitespace, not just against the immediately preceding line.
- **When adding an optional free-form prose section to a file whose header comment is itself an
  HTML `<!-- ... -->` block, never embed another literal `<!-- ... -->` inside that same outer
  comment's text** — the string `-->` appearing anywhere before the outer comment's real closing
  `-->` terminates the HTML comment early when any HTML-aware tool parses it, corrupting everything
  after. Caught this in my own first draft (writing "...unless declined and recorded in a
  `<!-- declined: <type> -->` comment line..." as prose _inside_ the outer header comment) before
  committing — the fix is to describe the mechanism in plain words ("recorded — see the Decline
  record convention below") and never reproduce another HTML comment's literal delimiters inside
  the text of a comment that's still open.
- Re-confirmed the NA-25/NA-27/NA-43/NA-51-round-1 lesson about avoiding "This story ships..."
  phrasing in a permanent plugin artifact — caught myself reintroducing the identical anti-pattern
  in a _new_ paragraph (the just-added docs-manifest-template.md Voice & format section, "this
  story ships zero generation logic") immediately after having fixed the same phrasing elsewhere in
  the same PR round. The instinct to explain "why this doesn't do X yet" by naming the current
  story is strong and recurring — actively grep any newly-authored paragraph in a permanent
  artifact for "this story" / "this PR" / "current story" before considering it done, don't rely on
  having fixed it once already in the same file.

## NA-51 — doc-type registry + docs-manifest scaffold (`plugins/sdlc/refs/doc-types.md`, `plugins/sdlc/refs/docs-manifest-template.md`, `plugins/sdlc/commands/init.md`)

- **A `##`/`###` Markdown heading is only the text on its own physical source line — wrapping a
  long heading across two physical lines (no leading `##` on the second line) does NOT continue
  the heading; it silently truncates the heading to line 1's text and turns line 2 into a
  freestanding paragraph directly underneath.** `prettier --write` (`proseWrap: preserve` in this
  repo) does **not** rejoin it for you, so this is a self-inflicted, `prettier`-invisible defect —
  it happened to THIS memory file's own previous NA-51 entry in the prior round, corrupting its own
  section heading. Never manually wrap a heading line; if it is long, let it stay long as one
  physical line.
- **`prettier --write` silently treats any path outside the repo, or under a `.gitignore`d
  directory (e.g. this repo's own `.tmp/`), as "ignored" and leaves it byte-for-byte unchanged —
  `prettier --file-info <path>` reports `{"ignored": true, "inferredParser": null}` for both
  cases with zero error output from `--write`.** This makes the established "verify in a scratch
  copy, run `--write` twice, confirm idempotent" protocol from prior NA-25/NA-27/NA-43 memory
  entries **silently useless** if the scratch copy lives outside the repo (e.g. a session tmp
  scratchpad) or under `.tmp/` — every "STABLE" result from such a copy is a false negative, not
  evidence of anything. The protocol only produces a real signal when the copy sits at a real,
  non-ignored path inside the repo, or is the real target path itself (reset with `git checkout --`
  instead of a tmp copy). Always confirm with `prettier --file-info <path>` that `ignored: false`
  before trusting any stability result from that path.
- **Correction to this file's own prior-round entry, which reached the wrong conclusion and shipped
  a QA-caught defect.** `plugins/sdlc/commands/init.md`'s Step 0 "Refresh skills" numbered sub-list
  (nested inside an outer numbered list → bulleted option → nested numbered "Steps:" list) is
  genuinely `prettier --write`-non-idempotent even on an untouched `git checkout --` copy — that
  part of the prior diagnosis was correct, and it IS pre-existing repo drift, not something this
  story's edits introduced. But the prior round's response — decide it's "out of scope", leave the
  section untouched, and let the pre-commit hook's mandatory reformat produce and commit whatever
  mangled form it emits (a collapsed run-on list with a code span `` `claude plugin update
<plugin>@<marketplace> --scope project` `` split across two physical lines, dedenting the second
  line to column 0) — was wrong: QA correctly flagged the committed, rendered defect regardless of
  whose commit introduced the _cause_. "Pre-existing instability I didn't cause" is not a reason to
  ship a broken rendering; the fix obligation travels with whoever's commit is the one that actually
  contains the mangled text on disk. **The real fix was cheap and root-caused correctly on the
  second attempt:** the failure was never really about nesting depth alone — it was a **code span
  split across a hand-wrapped physical line** (`` `claude plugin update\n<plugin>@<marketplace>
--scope project` `` — the exact CommonMark hazard already documented in the NA-7 gtm memory entry:
  a code span's embedded line break renders as a literal space, and remark's paragraph reflow
  around it inside deep list nesting is what actually broke). Flattening the nested "Steps:" ordered
  list into plain prose sentences ("First, ... Then ... Finally, ...") — dropping the nesting from
  3 list levels to 2 — **and** moving the multi-backtick code span onto a single unwrapped physical
  line together fixed it completely: the file went from ~22 non-idempotent hunks (many pre-existing
  and unrelated to this defect, e.g. GFM table column-padding, `*em*`→`_em_` conversion) to fully
  `prettier --write`-stable on the very first pass (pre-format bytes == post-format bytes,
  confirmed via `diff`). Lesson: when a "pre-existing, not my fault" defect is flagged in review on
  a file your commit touches, don't defer to "out of scope" — try the actual root cause (search for
  a split code span or other CommonMark hazard near the corruption site) before concluding it's
  unfixably fragile; the nesting-depth framing was a red herring that led to giving up too early the
  first time.
- The `plugins/sdlc/skills/skill-creator/scripts/quick_validate.py` script hard-requires a
  `SKILL.md` file (prints `"SKILL.md not found"` and exits 0 for any other filename) — it cannot
  validate a command file's frontmatter. For a story that only touches `commands/*.md` frontmatter,
  the correct fallback (per this story's own plan) is `head -12 <file>` plus a manual check that the
  `---`-delimited block still parses as a single-key `description` scalar — there is no other
  bundled validator for command frontmatter in this plugin.
- A markdown table's header row (`| type | quadrant | ... |`) is not stable to grep for by its raw
  literal spacing once `prettier --write` has column-padded it — the padding pass inserts
  variable-width spaces between the pipe and each header word. Match structurally instead
  (`line.startswith("| type") and "quadrant" in line`), not by the exact original spacing, in any
  script that locates a registry/manifest table programmatically (self-check scripts, CI lint, a
  future `/sdlc:docs` generator reading `refs/doc-types.md`).
- **Gating a new opt-in prompt/write-step ("only when X was accepted") is not enough when the same
  command has an existing bypass path that skips the step where X is normally asked.** `init.md`'s
  Step 0 "Merge new findings" guard jumps straight to Steps 4b/4d/4e (and now 4g) without re-running
  all of Step 3 — it only re-asks fields discovered via a template-token diff against
  `refs/project-context-template.md`. A brand-new Step 3 `AskUserQuestion` that is **not** a
  project-context token (this story's docs opt-in) is therefore unreachable on a Merge run under a
  naive "gate 4g on Step 3 acceptance" rule — QA caught this as an AC5 reachability gap, not merely
  a wording nit. Fix pattern for any future Step-3-adjacent opt-in: gate the downstream write step
  on "(accepted this run) OR (its artifact already exists from a prior run)", and explicitly state,
  next to the opt-in's own re-init-semantics prose, that a Merge run re-prompts it keyed on **the
  artifact's absence**, not on appearing in the template-token diff loop. Whenever a spec/plan adds
  a Step-3 confirm that writes a file outside `project-context.md` itself, check by hand whether
  Step 0's merge-bypass path can actually reach that confirm — don't assume "it's a normal Step 3
  field" without tracing the bypass.

## NA-58 — QA fix round on commit 9786198 (`plugins/sdlc/skills/writing-docs`)

- Wrote a skill description for `writing-docs` at 1162 chars without ever checking it against the
  plugin's own vendored validator — `writing-adrs`'s sibling description is 820 chars and passed
  silently, so nothing in the authoring flow surfaced the limit until QA ran
  `plugins/sdlc/skills/skill-creator/scripts/quick_validate.py plugins/sdlc/skills/<name>`
  explicitly. That script (bundled at that exact path in this repo, part of the vendored
  `skill-creator` skill) is the plugin's own executable AC-3 "passes the plugin's skill
  conventions" check — run it on every new/edited `SKILL.md` in this plugin as a matter of course,
  the same way `prettier --write` is run for formatting stability, rather than eyeballing
  description length. It also enforces `name` kebab-case/length, frontmatter allowed-keys, and "no
  angle brackets in description" — all worth checking in one pass, not just length.
- The over-limit sentence was almost entirely a duplicate of the skill's own "When to Use" body
  section ("Triggered by the sdlc docs pipeline… and by anyone hand-authoring a doc…") — the
  frontmatter description and the body's first prose section had independently grown to say nearly
  the same thing, once from a triggering-optimization angle and once from a "here's when to apply
  this" angle. When trimming an over-limit description, check the body for a section already
  covering the same ground before rewriting from scratch — here the fix was a straight deletion
  (the body's "When to Use" section already carries the full list), not a rewrite, once that
  duplication was spotted; just folded the highest-value trigger phrases from the deleted sentence
  into the surviving lead sentence so no triggering signal was lost, only the duplicate framing.
- A parenthetical aside drafted under time pressure ("or the skill's own knowledge if the pipeline
  output is available") read as sensible to me while writing it but was genuinely unparseable to a
  fresh reader — it conflated two different things (whether `docs/adr/index.md` exists vs. whether
  some other unspecified "pipeline output" is available) into one ambiguous clause. When a review
  flags a parenthetical as "garbled" rather than "wrong," the fix is usually to name the two things
  separately rather than trying to preserve the original single clause's wording — here that meant
  splitting into "check the index if the repo has one" plus an explicit "skip this check entirely
  if the repo has no `docs/adr/` directory at all," which is both clearer and a strict improvement
  (the original silently had no answer for the no-ADR-pipeline-adopted case at all).

## NA-58 — `writing-docs` skill for the future `/sdlc:docs` pipeline (`plugins/sdlc/skills`, `plugins/sdlc/agents/knowledge-engineer.md`)

- Same "ship the skill ahead of its own consumer" shape as NA-44's `writing-adrs`, but this time a
  live consumer (`knowledge-engineer.md`) already exists, since NA-43 landed it — so unlike NA-44,
  this story DOES touch the agent file: added `writing-docs` as a conditional (not always-load)
  Skill-tool load, worded "before drafting any prose documentation type" rather than folded into
  the unconditional "Required skills (load FIRST)" numbered list, because a pure ADR seed/distill
  dispatch never touches docs and shouldn't be forced to load a skill it won't use. Also extended
  the `Skills loaded:` return-line prose to name `writing-docs` as conditional, mirroring how the
  four always-loaded skills are named there unconditionally.
- Fetched all five relevant Diátaxis canon pages in full (`/`, `/tutorials/`, `/how-to-guides/`,
  `/reference/`, `/explanation/`, `/compass/`) via `curl -sL` + an inline Python HTML-strip, same
  approach NA-44 used for its ADR canon sources — this session's tool list again only exposed
  Read/Write/Edit/Bash/Skill, no context-mode MCP fetch/index tools were actually callable despite
  the dispatch prompt's context-mode banner, so Bash `curl` was the only usable option.
- A skill frontmatter `description:` field containing a URL followed by a colon-space sequence
  (e.g. `(https://diataxis.fr/): every document` — the colon sits between the URL's closing
  paren and the next word, not inside the URL itself) breaks a plain-scalar YAML parse with
  "mapping values are not allowed here," even though the `://` inside the URL itself is harmless.
  `://` never breaks a plain scalar (no space after the colon); any OTHER bare `: ` later in the
  same unquoted scalar does. Fix: rephrase to avoid the colon-space (here, swapped to an em dash —
  "(see https://diataxis.fr/) — every document…") rather than quoting the whole description block,
  since every sibling skill/agent description in this plugin uses an unquoted plain scalar and
  mixing styles would be inconsistent. Always parse a new/edited skill's frontmatter with a real
  YAML loader (`python3 -c "import yaml; yaml.safe_load(...)"`) before committing — visual
  inspection of a long description line does not reliably catch this.
- Confirmed via `git show f4250c4 --stat` (NA-44's own commit) that adding a net-new plugin-bundled
  skill with a not-yet-wired-in consumer touches only the `SKILL.md` + memory file — no
  `skills-map.yml` entry (that registry is for skills registered as _suggestions to consumer
  repos_, e.g. `atomic-design`; internal agent-consumed skills like `writing-adrs`/`writing-specs`/
  `writing-docs` were never added there) and no `README.md` update in the same commit (README's
  `knowledge-engineer` section only picked up ADR-pipeline prose in a LATER, separate docs commit
  once the full `/sdlc:adr` command existed). Followed the same precedent here: no `skills-map.yml`
  or `README.md` touch for `writing-docs` — that's the right scope for the future `/sdlc:docs`
  command story (NA-51+), not this one.
- Confirmed (via `git log -- plugins/sdlc/.claude-plugin/plugin.json`) that every prior commit
  shipping new content under `plugins/sdlc/` bumps `plugin.json`'s version in the same commit
  (0.31.0 → 0.32.0 for writing-adrs's own follow-up fix, 0.32.0 → 0.33.0 for the knowledge-engineer
  agent + `/sdlc:adr` command) — bumped 0.33.0 → 0.34.0 here for the same reason (pinned consumers
  won't see the new skill or the agent's updated Skill-load instructions otherwise). No version pin
  for individual plugins exists in `.claude-plugin/marketplace.json` (it only lists `name`/
  `source`/`description` per plugin) — nothing to update there.
- A "Reference template" worked example illustrating two entries needed a triple-backtick example
  snippet nested INSIDE the outer fenced code block showing the whole template — writing the outer
  fence as also-triple-backtick is genuinely CommonMark-ambiguous (the inner ```closes the outer
fence early, the same fence-length-matching rule the NA-27 memory entries already documented for
a different file). This repo's real`prettier --write` didn't reject it or error — it silently
"repaired" the ambiguity by widening the outer fence to 4 backticks but left the closing fence
exactly where the (now-prematurely-terminated) 3-backtick pair had been, which meant the second
illustrative entry (`## [Next symbol/command/field name]`) and its `...`leaked OUT of the code
block as real rendered headings, and a orphan 4-backtick closer was left dangling with nothing
left inside it — a **new**, first-time-seen variant of the "pre-commit write silently corrupts
content it didn't flag as wrong" family from NA-27/NA-25/NA-43: this time the corruption showed
up on the very FIRST`prettier --write`pass (not a later one), and the second (verification)
pass reported "unchanged" — meaning a same-file two-pass check alone does NOT prove no corruption
happened, only that whatever the first pass produced is now stable. Fix: read the post-prettier
file back with the Read tool and manually verify fence balance (or run a small script that pairs
every fence-opening line's backtick length against its closer) any time a SKILL.md/doc draft
contains a fence nested inside another fence — never trust "prettier ran with no errors" as proof
the nesting survived intact; widen the OUTER fence one backtick beyond the longest fence run used
anywhere inside it before the first`--write`, don't wait for prettier to "fix" it for you.

## NA-7 QA fix round 2 on PR #103 (`plugins/gtm`)

- gtm is a published plugin installed into arbitrary consumer repos, most of which have no
  `.claude/project/project-context.md` at all (that file is an sdlc-plugin artifact this agent
  wrongly assumed was universal). Hardcoding `gh pr create --base develop` meant every consumer
  repo whose default branch is `main` would silently open zero PRs. Fix: resolve the base branch
  at runtime with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, and treat
  project-context's `Base branch` token as an optional override only when that file happens to
  exist and sets one. Lesson: any gtm-plugin instruction that reaches for an sdlc-owned artifact
  (project-context.md, its Base branch row, etc.) needs an explicit "this file may not exist"
  branch, not a bare read — gtm and sdlc are installed independently and neither depends on the
  other.
- A rubric with 21 checks phrased as "the PASS condition" and 1 check (META-4) phrased as "the
  FAILURE condition" is a real bug, not a style nit, under a "finding = check fails" evaluation
  rule: the odd-one-out check fires on exactly the pages that are actually fine and stays silent
  on the pages that need the flag. When a rubric or any other checklist-style table states most
  rows in one polarity, grep the whole table for rows that read as a negative/failure description
  before shipping it — a single inverted row is easy to miss in review because it still reads as
  sensible English in isolation.
- Scoping a text-extraction grep to "the whole PR body" instead of to a specific named section is
  a latent false-positive generator the moment ANY other part of the body can start a line with
  the same token shape the grep targets. Here, the finding-ID grep (`- ` followed by a
  backtick-quoted kebab token) also matched the `## Summary` section's own bullets, since group
  and category slugs are also backtick-quoted kebab tokens. Fix: scope with a `sed -n` range over
  the target heading before the grep, so extraction only sees the section whose line shape the
  grep assumes. Generalizable rule: when a convention document
  defines a specific section for a structured extraction target, and the same body ALSO contains
  other free-form sections that could coincidentally match the same line pattern, always scope
  the extraction to the named section first — never grep the whole document and trust the pattern
  alone to disambiguate.
- The idempotency-guard input contract only ever covered OPEN PRs (by design — that's the set a
  fresh audit needs to avoid duplicating). But a PR that gets closed WITHOUT merging leaves two
  things behind that the open-PR-only contract can't see: its remote branch (a future run's
  fresh branch of the same slug collides on push) and its finding IDs (never actually fixed, so
  the next audit re-detects them and tries to re-propose them under a branch name that's already
  taken). The fix has two independent parts that are each worth remembering on their own: (1) a
  `git ls-remote --heads` probe before every push, with `--force-with-lease` reuse when a stale
  branch is found — probing before pushing is cheap and turns a hard push-rejection failure into
  a handled case; (2) an explicit written policy on WHETHER closure means permanent rejection
  (chosen here: no — closing without merging doesn't retract the underlying doc issue, so
  re-proposing is the correct default, but a different agent/tool might reasonably choose the
  opposite policy and must say so explicitly rather than leaving the behavior implicit).
- Replacing an "N+1 gh calls" pattern (`gh pr list` then `gh pr view` once per result) with a
  single `gh pr list --json headRefName,url,body` has one non-obvious wrinkle: `body` is
  multi-line text, so a naive `--jq '.[] | "\(.headRefName)\t...\(.body)"'` TSV-per-line approach
  breaks immediately, since the embedded body newlines split what should be one logical row
  across several physical lines. `jq -c '.[]'` (compact mode, run locally — not another `gh`
  call) is the fix: it escapes embedded newlines as `\n` inside the JSON string, so each PR still
  occupies exactly one physical line of loop input, and per-field extraction becomes a second,
  purely local `jq -r` call per line rather than a second network round trip.
- A command's error-handling table that restates 8 of a dispatched agent's 9 rows nearly verbatim
  is pure duplication risk (two copies of the same behavior contract that WILL drift the next
  time only one gets edited) with no reader benefit, since the command's own step 5 already
  surfaces the agent's return verbatim. Slimmed it to the 3 rows that are genuinely
  command-level (precondition STOP, plugin-root marker write, config-fallback note) plus one
  pointer row naming the agent's own Error Handling table as the source of truth for every
  audit-time scenario — the same "one source of truth plus pointers" pattern already established
  for cross-file shared-contract prose in the sdlc plugin.
- While rewriting the base-branch and stale-branch prose above, found (unprompted by this round's
  named findings) that several sentences had a single-backtick code span split across two
  physical source lines by manual wrapping, e.g. a `.claude/project/` path and a
  `gh pr create --base ...` command each broken mid-span. This is not just ugly source — per
  CommonMark, a code span's embedded line ending is converted to a literal space when rendered,
  so a path or command broken mid-span can render with a spurious space inserted in the middle of
  a literal token. Fix: never let a manually-wrapped sentence break a code span across lines;
  since this repo's prettier config has `proseWrap: preserve` (confirmed in earlier NA-25 work),
  it never rewraps prose for you, so the safe default for any sentence carrying a long inline
  code span is to just write it as one long physical source line rather than hand-wrapping it.
- Re-verified this round's own memory-file edits (this entry, plus the `patterns.md` fix) survive
  a real two-pass `prettier --write` before committing, per the now-established scratch-file
  protocol from the previous round's self-inflicted corruption — draft in a scratch file under
  the repo tree, run `prettier --write` twice and confirm the second pass is a no-op, THEN copy
  the verified text into the real file. Held for this round too; no corruption this time.
- A "fix the flagged line" edit to `patterns.md` appeared to silently vanish on the first attempt
  this round: I fixed lines 45 and 48, ran a bundled `prettier --write` across five files, saw
  "unchanged" on the second pass, moved on — then a later `git status` showed the file byte-
  identical to `HEAD`, meaning the fix never actually landed. Root cause, found by isolating the
  file and re-running `prettier --write` alone: two OTHER lines in the same blank-line-separated
  paragraph (46 and 47, neither flagged by the review, neither touched by my edit) contained the
  same invalid nested-backtick-escape anti-pattern from earlier rounds (a literal backtick inside
  a single-backtick code span written as a backslash escape, which CommonMark does not support).
  Prettier's remark parser treats the whole four-line paragraph as one reflow unit, so editing
  ANY line within it can shift where the corruption lands on the NEXT prettier pass — it moved
  from the lines I'd just fixed onto two lines I hadn't touched, which is why a same-file,
  same-command sanity check looked clean right after my edit but a later independent check showed
  the fix gone. Lesson: when a paragraph contains this anti-pattern anywhere, the WHOLE paragraph
  is unstable, not just the specific line with the bug — fix every nested-backtick-escape in the
  paragraph in the same pass (convert to a proper double-backtick delimiter, or drop the literal
  regex from prose entirely and describe it in words), and verify with an isolated, single-file
  two-pass `prettier --write` plus a `diff` against the pre-edit copy — a bundled multi-file
  prettier run's summary output is not a reliable enough signal that a specific file's specific
  fix actually survived; check that one file in isolation.

## NA-7 QA fix round 1 on commit 93c24e9 (`plugins/gtm`)

- `tr -d` deletes every occurrence of each character in its argument set, not just leading/trailing
  ones. Using it to strip the `- `, backticks, and space framing a parsed finding ID also strips
  every hyphen inside the ID, since hyphens were already in the delete set for a different reason
  (the list-marker separator) — `readme-missing-h1-keyword` came out as `readmemissingh1keyword`,
  silently breaking every future idempotency match. Fix: anchor a `sed` capture group instead —
  `sed -E 's/^- `([^`]+)`$/\1/'` — whenever a parsed payload can contain the same characters used
  as its own framing/delimiters, reach for an anchored regex capture group, not `tr -d`.
- An idempotency guard keyed only on a "group slug vs. branch name" match silently breaks the
  instant a re-run's grouping heuristic (fewest-PRs-possible, corpus-size-dependent) produces a
  different shape than a prior run — e.g. run 1 merges everything into `gtm/docs-audit/all`, run
  2's larger corpus splits per-category into `gtm/docs-audit/metadata` etc.; slug-level matching
  alone sees no collision and re-opens PRs for already-covered findings. The durable fix is a
  two-layer guard: a finding-ID-level filter (drop any finding whose `id` already appears in any
  existing open PR's claimed IDs, checked before the grouping heuristic even runs) as the primary
  defense, plus the original slug-level check retained as a cheap defense-in-depth secondary layer
  for the now-rare case a group's final slug still collides. When a review finds "guard operates at
  the wrong granularity," check whether the guard needs a second, finer-grained layer added before
  the existing one rather than just changing what the existing layer compares.
- A dense mesh of cross-file "step N" prose citations (command step to agent step to ref step, each
  file numbering its own steps independently) is exactly the kind of thing that goes stale the
  moment any numbered step gets inserted or reworded during a later fix round — inserting the new
  finding-ID-filter content as extra prose inside the existing Step 3 (rather than as a new
  numbered step) was a deliberate choice to avoid cascading every downstream step number and its
  citations. When a fix must add a step's worth of new behavior to an already-numbered,
  cross-referenced document set, prefer folding it into the front of the most relevant existing
  step over inserting a new numbered step, specifically to keep every other file's "step N"
  citations valid without a full renumbering pass. Still always finish with a blind
  `grep -n 'step[- ][0-9]'` across every touched file and manually verify each hit — don't rely on
  "I didn't renumber anything" as proof none went stale, since several citations in this round were
  wrong from the original authoring (not the renumbering), e.g. `docs-auditor.md`'s own
  input-contract line said "step-5 idempotency guard" when the guard was always Step 4, and a
  "future runs' idempotency check (step 5)" reference actually meant the sibling command file's
  Step 3 — cross-file references (agent citing command, command citing agent) are the ones most
  likely to be wrong on first authoring, since there's no single file where both numberings are
  visible side-by-side.
- A markdown table cell containing a bare, unescaped double-star-slash-star-dot-ext glob is not
  stable under this repo's real `prettier --write`. Writing the literal glob directly in a table
  cell (not inside a code span) is genuinely CommonMark-ambiguous emphasis syntax, so remark's
  formatter round-trips it to an escaped form on every `--write` pass — my first attempt to "just
  remove the backslashes" was silently undone the next time I ran prettier to verify idempotence,
  because the escaped form, not the bare form, is prettier's actual stable output for that raw
  shape. The fix that's genuinely stable, and matches this file's own established convention
  (the Postiz `Backend URL` and `API key env var` rows already wrap similar literal values in
  backticks), is to wrap each glob in its own inline code span, which sidesteps emphasis-parsing
  entirely (code spans aren't parsed for markdown syntax) and reads identically to how the same
  defaults are already presented in `commands/docs.md`'s Step 2 table. Lesson: when a "just fix
  the escaping" review finding involves asterisks in raw table prose, verify the fix with a real
  two-pass `prettier --write` run (not just a visual diff) before trusting it — and reach for a
  code span first, not a bare backslash-removal, whenever the token is glob- or regex-shaped.
- This exact memory file was itself corrupted by the repo's real `lint-staged`/`prettier --write`
  pre-commit hook in this round: an Edit-tool draft mixing `*single-asterisk*` italics with
  backtick code spans placed immediately adjacent to punctuation (no surrounding space) caused
  remark to reflow the paragraph and drop the spaces around several code spans entirely (e.g.
  `` `tr -d`has no concept `` — backtick glued straight onto the next word), and a bullet that
  described a literal `**/*.ext`-shaped glob in prose suffered the exact same corruption the bullet
  was warning about. Confirmed via `git show HEAD:<file>` after the commit, per the established
  "pre-commit `--check`/`--write` dry run never proves what actually lands" lesson — this time the
  corruption happened on a file that was never dry-run tested before committing at all. Fix: for
  any memory bullet mixing heavy backtick usage with emphasis markers, draft it in a scratch file
  under the repo tree first, run a real two-pass `prettier --write` there to confirm both stability
  and non-corruption, and only then copy the verified-stable text into the real file — don't trust
  Edit-tool content to survive the commit hook unchanged just because the file being edited "is
  just documentation."

## NA-6 — content-writer agent + voice-rules ref + /gtm:site command (`plugins/gtm`)

- A plan's structural verification grep can accidentally match its own explanatory prose. The
  NA-6 plan's Task 3 check `grep -cF '.claude/.gtm-plugin-root' plugins/gtm/commands/site.md`
  expects `0` to prove "no accidental agent resolver block" — use `-F` (fixed-string) on the full
  marker path: an unescaped-dot regex (`grep -c '.gtm-plugin-root'`) matches any char before the
  token and counts unrelated prose. Also: a sentence merely _explaining_ "there is no
  `.claude/.gtm-plugin-root` resolver block here" trips the count — when a verification grep
  detects a structural artifact, don't name the artifact's literal marker in nearby prose; name the
  _mechanism_ generically ("no plugin-root resolver block"). Always run the check for real rather
  than eyeballing the regex.
- The gtm plugin's shared-gate boundary (`copy-editing` lives only on the command's gate step, never
  on the content-producing agent's `skills:` list) is easy to verify precisely: grep the file for
  the skill name and manually confirm the hit sits in prose ("deliberately not on this list") rather
  than inside the `skills:` YAML block — a bare occurrence count doesn't distinguish the two.
- When a spec's plugin-root convention differs by artifact type (commands get
  `${CLAUDE_PLUGIN_ROOT}` natively; agents resolve it via a `.claude/.<plugin>-plugin-root` marker
  file), copy the agent-side resolver header block **verbatim** from the established pattern file
  (here, `product-marketing-manager.md`) rather than re-deriving it — a byte-diff against the
  source is the cheapest verification and the plan expects verbatim reuse, not a rephrase.
- This story's worktree started on a synthetic `worktree-agent-<hash>` local branch one commit
  behind `origin/feat/NA-6` (the plan-writer's commit hadn't been merged into this worktree's local
  ref yet). `git checkout feat/NA-6` failed because that branch was already checked out in a
  sibling worktree (`git worktree list` showed it). Fix: `git merge --ff-only origin/feat/NA-6` on
  the current branch — safe since the local ref was a strict ancestor — rather than trying to force
  a branch switch that git's one-worktree-per-branch rule disallows.

## NA-4 — per-channel ownership picker (`plugins/gtm`)

- `plugins/gtm/refs/*.md` protocol refs are thin and delegate fully to the `postiz` CLI — never
  hand-roll HTTP. New refs (e.g. `channel-config.md`) should mirror `postiz-verify.md` /
  `product-detect.md`: an intro line naming which `/gtm:init` step applies them, then concrete
  sections (no TBDs), ending in an error-handling table the calling command step can defer to
  instead of re-specifying inline.
- `marketing-context-template.md` deliberately keeps its own `<...>` placeholder tokens throughout
  (e.g. `<name>`, `<one-liner>`) as a _documented convention_ for "value inserted at write time" —
  when grepping for stray placeholders across gtm refs/commands, these pre-existing tokens (and
  prose that mentions `` `<...>` `` descriptively) are expected noise, not drift. Only flag a
  genuinely new/unintended `<...>` token introduced by an edit.
- When a command step (e.g. `/gtm:init` Step 4b) is written to _defer_ to a ref for enum/error
  detail rather than restate it, don't expect a verification grep for that enum text to also match
  in the command file — that's by design (single source of truth lives in the ref), not
  inconsistency.
- Multi-file plans in this plugin (ref + template + command) hinge on keeping enum lists, defaults,
  and table column order byte-identical across all three files — do the verification greps
  (Task 4-style) as the last step even when confident; cheap and catches transcription drift early.

## NA-4 review-fix follow-up

- `marketing-context-template.md`'s `## Template` fence is _rendered verbatim_ into every generated
  `.claude/project/marketing-context.md` — never put writer-facing meta-instructions (empty-list
  exception prose, enum catalogues, anything with an `${CLAUDE_PLUGIN_ROOT}`-style unresolvable
  reference) inside that fence. Only actual template markup belongs there; explanatory prose about
  the template goes below the closing fence, near `## Schema` or folded into the matching
  `## Fill rules` entry — don't duplicate the same rule in two places, extend the existing Fill
  rule instead.
- When a Step-6-style summary line lists "this unblocks story X, Y, Z" and the very story this run
  implements is itself one of X/Y/Z, drop it from the unblocked-list and say its config now exists
  — a blanket "none of their config exists yet" claim placed after a per-run "N configured" line is
  self-contradicting and a reviewer will catch it.

## NA-4 review-fix follow-up (round 2)

- A "verbatim fence" convention is only as safe as its placeholder gate: if the fence's illustrative
  sample rows/values are concrete-looking (not `<...>` tokens), the Fill-rule-1 style gate ("replace
  every `<...>` token") can't catch them leaking into a fresh-run render. Fix pattern: keep the fence
  itself to the true default/empty state (e.g. header + separator row only), and move illustrative
  "here's what a filled example looks like" content _below_ the closing fence, explicitly labeled
  illustrative (near `## Schema`, not folded into the fence). Illustrative example rows may still use
  the `<id>` convention for cells that are always run-generated — that's consistent with the rest of
  the template's placeholder style and with the plan's verification grep (`grep -v '<id>'`).
- When a parenthetical cites "a downstream story" by describing its function (not its key), and that
  description turns out to match the very story doing the current edit, don't just note the story is
  self-referential — check what the _actual_ downstream consumer is (grep sibling Fill rules/schema
  rows for the same concept) and reword the parenthetical to name that real downstream capability
  (e.g. "voice overrides / content strategy") instead of leaving a self-referential description in place.
- Meta-instructions to the _executor_ (e.g. "note X here" / "remember to include Y") must never sit
  inside a print-verbatim blockquote meant for the _end user_ — even a single parenthetical line. Pull
  it out as a plain instruction sentence immediately before the `Print a summary:` cue, not as another
  line inside the `>` block.
- When one step's instruction is phrased as an unconditional loop ("for each channel, prompt...") but
  a sibling step (e.g. Step 0's Merge path) already carves out an exception (only prompt genuinely new
  items), add a short forward-pointing clause at the unconditional step rather than assuming the
  reader will infer the exception from the other step alone — cross-step conditionals need an explicit
  breadcrumb at both ends.

## NA-4 review-fix follow-up (round 3)

- Never assume a CLI's documented/skill-modeled output shape (e.g. "returns a JSON array, pipe
  straight to `jq`") is what actually comes out on stdout — a human-readable preamble line before
  the JSON is a common real-world CLI pattern. When a ref delegates enumeration to a CLI, make the
  parse defensive (extract from the first line starting with the expected structural character,
  e.g. `sed -n '/^\[/,$p'`) and give the "zero exit but nothing parseable" case its own distinct
  STOP message — folding it into the transport/connection-error message misdiagnoses a CLI-version
  or output-format problem as a backend-reachability problem, sending the founder down the wrong
  troubleshooting path.
- A "refresh only the stable-identity field on re-run match" rule is incomplete if a _display_
  field (e.g. `Name`) also participates in the fallback match key — display data still needs
  refreshing every run, or a later rename silently breaks the fallback the _next_ time the primary
  key goes stale. When a rule like this changes, update it in every place it's stated (ref
  re-run-matching bullet, template schema column note, template fill rule, command step if it
  restates) — don't leave one copy saying "only field X" after another now says "X and Y".
  Explicitly note in the ref when a later fix deliberately supersedes wording carried over from an
  earlier merged spec, so a future reader doesn't think it's a transcription slip.
- A step that only _gathers into an in-memory model_ (writes nothing to a final path) must never
  use the verb "write" for what it does with the empty-list case either — "record ... into the
  in-memory model; a later step renders it" keeps the step's own no-write contract intact even for
  its edge cases.
- An "atomic staging guarantee leaves X untouched" claim is only true for the paths _that step's
  own atomic write_ covers. On a Merge/Re-run path, an earlier step (e.g. a marketingskills skill
  invocation) may have already mutated a file _outside_ that atomic write (e.g.
  `.agents/product-marketing.md`) before this step's error occurs — state the STOP's write-nothing
  scope precisely (which file(s) truly weren't touched) and point at how to reconcile the file that
  might already have moved (re-run the command to resync).
- Prefer per-item three-way outcomes (drop / retain-and-flag-stale / abort) over an all-or-nothing
  decline gate whenever one declined item shouldn't cost the founder every other answer already
  gathered in the same run — model the "decline" outcome as an _explicit, distinct_ abort action,
  not the default branch of a single yes/no per affected item.
- `grep -v '<pattern>'` on whole lines silently hides any other match that happens to share a line
  with the excluded pattern. For a "no stray placeholder" style check, scan token-by-token with
  `-o` (`grep -onE '<[^>]+>' files | grep -v ':<line-anchored-exact-token>$'`) so the file:line
  survives and only the exact excluded token is dropped, not the whole line it lives on.
- When the same AC-n label is reused by two different stories in one file (NA-3's Step 0/2/3/4/6
  gates vs NA-4's Step 0-Merge/Step 4b additions), only the _newly added_ citations need the
  disambiguating story prefix (`NA-4 AC-n`) — leave every pre-existing citation as bare `AC-n`.
  Grep `AC-[0-9]` across the file first and sort hits by which story's section they sit in before
  touching any of them; qualifying a pre-existing NA-3 tag by mistake is itself a new inconsistency.
- A boundary condition stated only implicitly (e.g. "pre-selected to X" vs "skipped -> Y") should
  get one explicit sentence distinguishing "prompted and the default was accepted" from "never
  prompted/answered at all" — reviewers read these as the same case unless the text says otherwise.

## NA-5 — KPI metric and source setup (`plugins/gtm`)

- When a plan/spec's Task-4-style verification grep expects a multi-word token (e.g. `Custom
command`) to appear verbatim on a single line across three files, watch for prose line-wrap:
  Markdown source can hard-wrap a phrase like "Custom command" across two source lines (`Custom` at
  EOL, `command` starting the next), which is invisible when reading rendered Markdown but makes
  `grep -onE 'Custom command'` silently miss it in exactly one of the three files. Run the Task-4
  greps for real (not just by eyeballing the prose) and re-wrap any option/enum list so each locked
  token phrase sits fully on one physical line.
- When a spec gives an exact illustrative table (e.g. the `## KPI` nine-row example with concrete
  values like "GitHub stars" / "managed" / "128" rather than `<...>` placeholders) and says "add
  this exact shape to the fenced template block," follow that literally even though sibling
  sections (Product/Postiz) use `<...>` placeholders in the same fence — the two styles can coexist
  in one template file; add a short inline comment above the table clarifying it's illustrative
  ("row set fixed, values illustrative, source-irrelevant cells blank") so a reader doesn't mistake
  the concrete-looking values for what a fresh run would literally emit.
- A `$<field name>` illustration token (e.g. `$<Auth env var>`, showing how a stored string
  shell-expands a referenced env var by name at probe time) is a legitimate spec-inherited
  convention, not stray placeholder drift — when it appears verbatim in the spec's own locked
  wording, carry it into the ref as-is rather than "fixing" it to a bracket-free form.

## NA-15 — atomic-design skill (published-for-others, `skills/` + `plugins/sdlc/refs/skills-map.yml`)

- This repo's runner has no `pyyaml` preinstalled; a plan/spec YAML-parse verification gate
  (`python3 -c "import yaml..."`) fails with `ModuleNotFoundError` on a clean shell. Fix:
  `python3 -m pip install --quiet --user pyyaml` before running the gate — cheap, one-time, don't
  substitute a regex/grep check instead since the gate specifically wants a real YAML parse.
- Framework-agnostic content scans (AC-4-style, banning `react|vue|expo|...` tokens) must be scoped
  to skill _content_ only (`SKILL.md` + `references/*`), explicitly excluding the sibling
  `skills-map.yml` registration entry — that file legitimately carries the same framework names as
  `when:` detection triggers. Keep the grep's file list narrow rather than grepping the whole skill
  directory, or the registration metadata will produce false-positive "FAIL" hits.
- For a "published-for-others" skill (same class as `hono-api`/`typeorm`/`electrodb`), the negative
  checks that matter are: absent from `.claude/project/skills.json`, no `.claude/skills/<name>/`
  copy, and no agent-override binding — confirmed once per skill; don't add any of the three even if
  a later task seems to imply local consumption. Registration is `plugins/sdlc/refs/skills-map.yml`
  `source`+`path` only.
- When a plan gives an exact YAML block to append to `skills-map.yml` "after the `electrodb` entry,
  before the trailing comment block," insert it verbatim at that exact anchor — the file's trailing
  `# Frameworks / ORMs with no built-in skill suggestion` and `# Agent-to-skill domain mapping`
  comment blocks are documentation-only and don't require updating for a new entry unless the plan
  explicitly asks (it didn't here — left the per-agent summary comment untouched).

## NA-26 — enforce project-skill loading in domain-agent dispatches (`plugins/sdlc/refs` + `agents`)

- This story's dedicated worktree was checked out on a synthetic `worktree-agent-<hash>` branch,
  one commit behind `origin/feat/NA-26` — `git checkout feat/NA-26` failed with "already used by
  worktree at <main-repo-path>" because the main repo checkout (left over from `/sdlc:plan`) still
  held the branch. Fix: confirm the other worktree is clean (`git -C <path> status --short` empty,
  HEAD matches `origin/<branch>` exactly — no uncommitted work to lose), `git -C <path> checkout
<base-branch>` there to free the ref, then `git checkout feat/NA-26` in this worktree. Only do
  this when the other checkout is verified clean; never force-switch a dirty worktree.
- A plan's grep-based verification that expects an exact multi-word phrase ("read each directory
  guide it lists") to survive on one physical line can fail even on a file the plan tells you to
  edit only lightly (add a trailing clause) — if the file's _pre-existing_ prose already hard-wraps
  that phrase across two Markdown source lines, the phrase-preservation check fails through no
  fault of the new edit. Since the plan explicitly names this exact check in its Task 5 Step 4
  verification, re-wrap the existing sentence onto one line while inserting the new clause (cheap,
  in-scope since you're already touching that paragraph) rather than leaving it to fail silently.
- The plan's whole-story check `grep -rn "Behaviour\|behaviour" plugins/sdlc/refs/ plugins/sdlc/agents/
plugins/sdlc/README.md` — "Expected: none" — is written as if the tree starts clean, but this
  repo's plugin already carries plenty of pre-existing British-spelling prose in files/sections the
  story never touches (`triage.md`, `jira-bug-template.md`, `skills-manifest.md`,
  `project-context-template.md`, `solutions-architect.md`, and untouched paragraphs inside files
  this story DOES edit). Read "Expected: none" as "none _introduced by this story's edits_" — diff
  the flagged line numbers against your own edited spans before treating a non-empty grep as a
  failure; don't rewrite unrelated pre-existing prose to force a literal zero-match, that would be
  scope creep beyond the plan's named file/line anchors.
- A 12-file, prose-only contract story (no code, no data model) still benefits from running every
  task's own verification grep individually before the closing whole-story block — the per-task
  greps catch numbering-contiguity regressions (e.g. an inserted list item bumping every later
  number) that the whole-story greps don't check for.

## NA-26 review-fix follow-up

- Same worktree-branch-lock issue recurred, but this time the sibling worktree holding
  `feat/NA-26` (the repo's _main_ worktree) had already fast-forwarded to the branch's true head —
  freeing it via `checkout <base-branch>` there wasn't needed/available. When the dispatched
  worktree's own branch is a strict ancestor of the target branch (`git merge-base --is-ancestor
<local-HEAD> <target-branch>`), `git merge --ff-only <target-branch>` on the current
  worktree-local branch is the lower-risk fix — it never touches the other worktree, can't lose
  uncommitted work there, and leaves you on your own synthetic branch with the right file content
  and history, ready to commit. Reserve force-freeing the other worktree's checkout for when a
  true ff-only isn't possible.
- The playbook's per-sub-bullet consequence text ("On failure → STOP-and-redispatch...") reads as
  attached to only the _last_ sub-bullet under a two-case list unless it's dedented to the parent
  bullet's own paragraph indent (2 spaces under a `- ` top bullet, not 4 spaces continuing a nested
  `- ` sub-bullet). When a reviewer flags "this consequence should apply to both sub-cases,"
  dedenting by exactly the sub-bullet's own indent width (here 2 spaces) turns it back into a
  continuation paragraph of the parent bullet in Markdown's nesting model — no rewording needed.
- The `principal-engineer.md` agent file's prose (`## Collecting results`) and the playbook's
  authoritative rule (`## Step 5`) both name the same 3-vs-4-field return contract independently —
  when a playbook change adds a field to the domain-agent return contract (e.g. `Skills loaded`),
  grep the parallel agent-file prose for the old field count/list too (`grep -n "Extract"
plugins/sdlc/agents/principal-engineer.md`) — it's easy for the spec/plan to fix the playbook
  (source of truth) and miss the agent file's independent restatement of the same contract.

## NA-26 — PR #70 review, round 2 (10 accepted internal-contradiction findings, `plugins/sdlc/refs` + `agents` + `README.md`)

- A single Skills-loaded semantic rule ("what counts as invoked", "pass iff", "blocked exempt",
  "extras tolerated") was independently restated in up to 5 places (handoff Return format, principal
  playbook Step 5, QA playbook Step 3, README enforcement summary, and each of the 6 domain-agent
  profiles). When a reviewer finds a contradiction between two restatements, fixing only the two
  named sites isn't enough — grep every restatement site (`Skills loaded`, `pass iff`, `gate on
starting work`, `Project skills`) across the whole plugin before declaring done; a phrase can drift
  independently in a site the finding didn't name (here: README's summary paragraph, which nobody
  flagged directly but silently restated the pre-fix "none passes only when declared" wording).
- Established a durable "one source of truth + pointers" pattern for this kind of shared mechanical
  rule: principal playbook Step 5 owns the pass/fail mechanics for orchestrator-side verification;
  domain-agent-handoff.md's Return format owns the agent-side `Skills loaded:` semantics (including
  the preloaded-skill and no-instruction-fallback clauses). Every other site (QA playbook, README,
  the 5 sibling agent-profile `## Skills` paragraphs) should be a one-line pointer with only the
  consequence that differs locally (e.g. QA: "return blocked immediately, no redispatch" vs
  principal: "redispatch once then STOP") — never a full re-derivation. `grep -rn "pass iff"` across
  `refs/*.md README.md` after an edit is the cheapest way to confirm only the two source-of-truth
  files still contain the actual mechanics.
- A hardcoded doc-internal heading reference (e.g. "`## Project skills`" naming a specific override
  section heading) breaks the moment a real consumer override uses a different heading for the same
  concept (this repo's own `.claude/project/agents/ai-enablement-engineer.md` uses "## Skills
  (plugin-bundled — invoke via the Skill tool)"). Prefer describing the section by its _role_
  ("the override's skills section — whatever heading it uses, the section listing skills to invoke
  via the Skill tool") over quoting a literal heading string that other repos are free to rename.
- A "STOP-and-redispatch on Skills-loaded failure" rule silently collides with a sibling "zero new
  commits since pre-dispatch HEAD = silent failure" rule when the redispatch targets a phase whose
  code work already landed in the first dispatch — the redispatch produces zero _new_ commits by
  design (only the return-line semantics were wrong, not the code). Fix pattern: scope that specific
  redispatch as a narrow "verify already-committed work against the named skills; fix only if a
  skill mandates a change; re-emit a compliant return" prompt, and explicitly exempt it from the
  zero-new-commits STOP in the same sentence that defines the exemption trigger — don't leave the
  general rule and the exemption in two disconnected paragraphs a reader has to reconcile themselves.
- `git worktree list` showing `feat/NA-26` "locked" (checked out read-only in the repo's main
  worktree, left over from a prior `/sdlc:plan`/`/sdlc:impl` run) with the dispatched worktree
  sitting on a synthetic `worktree-agent-<hash>` branch one merge-commit _ahead_ of
  `origin/feat/NA-26` (a spec PR had merged into main and been merged back into the worktree branch)
  meant neither the prior story's "checkout the target branch" nor "ff-only merge the target into
  local" pattern applied cleanly. Since the task only needs this worktree's branch to fast-forward
  cleanly onto the target for the orchestrator later, `git reset --hard origin/<branch>` on the
  dispatched worktree's own synthetic branch (never on a branch checked out elsewhere) is the
  correct, lowest-risk move when the worktree's local history has _diverged_ from the target
  (not just lagged behind it) and the working tree is otherwise clean — confirm `git status --short`
  is empty before resetting, since `--hard` discards anything uncommitted.

## NA-27 — orchestrator-managed worktree + shared Nx cache + agent-reuse flag (`plugins/sdlc`)

- This story's dispatched worktree had NO `node_modules` at all (not stale — genuinely absent), so
  the very first `git commit` failed on the repo's `husky` pre-commit hook (`lint-staged` binary not
  found), not on anything story-related. `pnpm install --prefer-offline` (no `--frozen-lockfile`
  needed here since the lockfile was already correct) fixed it in ~30s via the shared pnpm store.
  Symptom to recognize fast next time: `ERR_PNPM_RECURSIVE_EXEC_FIRST_FAIL … "lint-staged" not
found` on a first commit attempt in a fresh worktree means `node_modules` is missing, not that the
  commit content is wrong — check `ls node_modules/.bin | wc -l` before assuming a real failure.
- A published, multi-repo plugin script that needs a per-repo config value the sibling scripts treat
  as an orchestrator-supplied positional arg (e.g. `<BASE-BRANCH>` in the playbooks/agent docs) can
  instead read it directly from `.claude/project/project-context.md` at runtime when the caller is a
  bare hook/script with no orchestrator handing it in (here: `worktree-gc.sh`, invoked bare from
  `SessionEnd` with zero args). Mirrored `read-review-config.sh`'s `read_token` sed/grep pattern
  (`^\|[[:space:]]*<Token>[[:space:]]*\|` → `[A-Za-z0-9_./-]+` capture, defaulted on read-failure)
  rather than inventing a new one — keeps the "read a single-value token row" convention in one
  recognizable shape across the plugin's scripts, and the `|| true` guards are load-bearing under
  `set -uo pipefail` for the exact same silently-swallow-no-match reason documented there.
- When a plan Task explicitly writes out a script's full case-by-case algorithm (here: Task 1 Step 3,
  the three idempotent worktree-resolution cases with their exact git subcommands per case), transcribe
  it near-verbatim rather than re-deriving the git plumbing — the plan had already resolved subtleties
  (e.g. case 1 fetches/merges via `git -C "$WT"`, not the primary root; case 2/3 fetch via the primary
  root) that are easy to get backwards if you rewrite from the prose summary instead of the literal
  step text.
- A prompt-contract numbered list that gains two new **mandatory first instructions** (cwd + Nx-cache,
  per spec §1/§3) is cleanest inserted as items 1–2 with every existing item renumbered down, rather
  than appended at the end — the spec explicitly calls them "the mandatory first instruction," and
  renumbering only the prose items (not the underlying meaning) is a pure count-shift with no risk of
  changing behavior, so do it directly instead of leaving a `1a`/`1b` insertion that reads oddly.
- For a per-file "mirror the playbook change in the agent doc" task (Tasks 9–10) where the spec's
  Files-changed table gives only a one-line description (not the full worktree/guard bash blocks the
  playbook carries), a condensed prose mirror is the right level of fidelity — the agent-file's own
  header already says "retained as background reference, playbook is source of truth," so duplicating
  every bash snippet there would create a second copy to keep in sync rather than one clean pointer.
- A plan task with an explicit escape hatch ("If no such prose exists, make no change and note it in
  the commit body") should actually take that hatch when true — grepping `plugins/sdlc/commands/
review-fix.md` for both `isolation` and `worktree` came up empty, so Task 8 produced no commit at
  all (an empty `git add` + `git commit` would fail with "nothing to commit"); the plan's own
  Files-changed table description ("inherits the idempotent provision via the QA playbook") was the
  tell that this file's isolation model was always implicit, never spelled out in its own prose.

## NA-27 QA fix round (`plugins/sdlc`)

- This dispatched worktree was one commit behind `origin/feat/NA-27` at start — the task's stated
  base SHA (`bf61700`) didn't match `HEAD` (`730b30c`, the pre-worktree-model spec-merge commit).
  Confirmed via `git branch --contains bf61700` that the local worktree branch was a strict ancestor
  (no divergence), then `git merge --ff-only origin/feat/NA-27` in the worktree brought it current —
  same low-risk pattern as prior stories' worktree-lag fixups, just via `origin/<branch>` fetched
  fresh rather than a sibling worktree's local ref.
- The most subtle finding in this batch (QA playbook Steps 5/6 running `git fetch && git merge
--ff-only` bare, i.e. in the session/primary cwd) only actually corrupts the primary post-NA-27:
  before the worktree model landed, the primary WAS the story branch (the ff-merge was a no-op /
  intentional sync), so the bug was latent until this same story's own worktree-model change made
  the primary sit on `<BASE-BRANCH>` permanently. A structural change to an invariant (here:
  "primary never checks out the story branch") can silently invalidate leftover commands elsewhere
  in the _same_ file that predate the invariant and were never touched by the change's own diff —
  grep the whole playbook file for every bare `git fetch`/`git merge`/`git add`/`git commit` (no
  `-C`) after landing a worktree-isolation change, not just the sections the plan's diff touched.
- Fixing "assert primary status is EMPTY" → "assert primary status matches ITS OWN pre-dispatch
  snapshot" needs the pre-existing-dirt escape hatch stated at the capture site too, not just the
  assert site — otherwise a reader only sees "snapshot, then compare" at the assert and might still
  read the capture-time comment (`# must be empty`) as a precondition the run should enforce. Update
  the comment at the capture line in the same edit as the assert line; don't leave one half of the
  paired instruction using old language.
- `git rev-parse --abbrev-ref HEAD` returning the literal string `"HEAD"` for a detached checkout
  (not empty, not an error) is an easy gate-writing mistake: a `[ -z "$WB" ]` guard reads as if it
  covers "unreadable OR detached," but detached HEAD produces a non-empty value and silently falls
  through to whatever check comes next. Any script deriving a branch name via `--abbrev-ref HEAD`
  needs an explicit `"$WB" = "HEAD"` guard as a _second_, separate condition — never assume the
  empty-check subsumes it.
- `bash -n` only proves parse-validity, not runtime-correctness of shell string-hashing logic (the
  `pnpm-lock.yaml` staleness check added here) — after writing it, trace the four cases by hand
  (missing node_modules / missing hash file / hash match / hash mismatch) rather than relying on
  syntax-check alone, since a portable-CLI script has no test harness in this repo to exercise it.

## NA-27 — external review-fix round on PR #72 (`plugins/sdlc`)

- Dispatched worktree was FIVE commits behind `origin/feat/NA-27` this time (`730b30c`, the
  pre-worktree-model spec-merge commit — the whole worktree-isolation implementation itself was
  missing), not the usual one-commit lag. Same fix pattern held: `git merge-base` confirmed the
  local branch was still a strict ancestor, so `git merge --ff-only feat/NA-27` (the branch ref, not
  `origin/feat/NA-27` — both resolve the same commit here and `git merge` doesn't require exclusive
  checkout, only `git checkout` does) brought the worktree current without touching the sibling
  worktree that had the branch checked out. Don't assume "one commit behind" from prior stories —
  always diff the stated base SHA against actual `HEAD` and `git log base..target` before assuming
  the gap is trivial.
- A GC race-condition fix (finding: guard compares a worktree's HEAD against the CURRENT base tip,
  which drifts once the base branch advances past the worktree's true creation point) is better
  fixed by recording an immutable "provision point" marker at creation time than by trying to make
  the race window narrower. Used **worktree-scoped git config** (`extensions.worktreeConfig true` +
  `git -C "$WT" config --worktree sdlc.provisionSha <sha>`) written ONLY in the two branches that
  actually create a new worktree directory (re-provision-after-teardown and first-run-from-base) —
  never in the reuse/fast-forward branch, since worktree-scoped config persists in that worktree's
  own `.git/worktrees/<name>/config.worktree` across every later idempotent re-invocation of the
  setup script, so re-writing it on reuse would silently reset the very reference point the guard
  depends on. Always keep an old-style fallback check (here: tip-equality against current base) for
  worktrees provisioned before the new guard existed and therefore have no recorded marker.
- A "Case 1 registration probe matches but the directory was removed out-of-band" bug needs the
  registration check split from the case dispatch: compute a boolean (`REGISTERED=...`), insert a
  `[ ! -d "$WT" ]` pre-check between the probe and the `if/elif/else` case chain that prunes the
  stale registration AND flips the boolean back to false, then dispatch on the boolean — this lets
  execution "fall through" cleanly into the branch-exists/create cases without duplicating their
  logic or fighting bash's linear if/elif structure.
- When a spec's package-manager token (`.claude/project/project-context.md` "Package manager" row)
  needs to drive both the install command AND the lockfile name/hash check, resolve it once into two
  paired variables (`INSTALL_CMD`, `LOCK_FILE_NAME`) via a single `case` statement with an explicit
  `*)` fallback that warns to stderr and re-assigns the pnpm defaults — this keeps "unknown token"
  and "pnpm" behaviourally identical (same code path afterward) rather than needing a separate
  guard later in the script.
- A "gate can false-green on untracked leftovers" fix (assert `git status --porcelain` is empty
  before the gate/before each phase's assertion) needs the exact same one-liner duplicated at BOTH
  the QA-playbook Step 6 (pre-gate) and the principal-playbook Step 5 (post-phase-commit) sites —
  they're structurally identical checks guarding different moments (before a shared quality gate vs.
  after every phase dispatch) and a reviewer finding one doesn't imply the other was already fixed;
  grep the whole plugin for `status --porcelain` before declaring a "shared worktree cleanliness"
  finding fully resolved.
- `impl.md`'s `--body "..."` quoted string is printed VERBATIM into the Jira comment, so a naive
  "restore column-0 continuation lines" fix is NOT prettier-stable when that fence sits nested
  inside an indented numbered-list item (`5.` here) — verified the hard way: the first commit's
  `lint-staged` (`prettier --write --ignore-unknown`) actually corrupted the fence (split it into
  two mismatched fences, leaked the quoted body out as bare paragraphs, broke the bash string).
  Root cause, confirmed by minimal repro (`printf` a 2-item list with a fenced block containing a
  dedented vs. indented blank-line continuation and diff `prettier --write` before/after): prettier's
  remark-based Markdown parser requires EVERY line inside a fence nested in a list item — including
  blank-line-separated continuations — to satisfy the item's content indentation (here 3 spaces,
  from `5. `); a column-0 continuation line breaks the parser's list-item/fence association at PARSE
  time, so no post-hoc `<!-- prettier-ignore -->` can glue the split nodes back together (ignore
  comments only suppress re-printing of already-correctly-parsed nodes, they can't fix a mis-parse).
  Re-indenting the continuation to 3 spaces "fixes" prettier-stability but reintroduces the exact
  content-corruption bug being fixed (the leading spaces leak into the literal Jira comment text).
  The actual fix that satisfies both constraints: DEDENT THE WHOLE FENCE OUT OF THE LIST ITEM (fence
  markers and body at column 0, not nested/indented under `5.`) — CommonMark still associates it
  visually with the preceding list item as long as there's no blank-line-terminated topic break, and
  prettier's parser no longer needs to reconcile fence-body indentation against list-item content
  indentation, so it leaves the block completely untouched (verified `diff` before/after `prettier
--write` = empty).

## NA-27 — Copilot fix round on PR #72 (`plugins/sdlc/scripts`)

- The dispatched worktree's own branch (a synthetic `worktree-agent-<hash>`) was, once again, a
  strict ancestor of `origin/feat/NA-27` (this time five commits behind, at `730b30c` — the
  pre-worktree-model spec-merge point). Same low-risk fix as prior NA-27/NA-26 rounds: `git
merge-base --is-ancestor HEAD feat/NA-27` to confirm no divergence, then `git merge --ff-only
feat/NA-27` (the local branch ref — `feat/NA-27` was checked out exclusively in the sibling
  primary worktree, so only `git checkout` there is blocked, not `git merge`). This is now a
  recurring pattern across at least 3 stories — always diff stated base SHA against actual `HEAD`
  before assuming a fresh worktree is current.
- A two-branch "admits local-OR-remote, but body always fetches/merges origin unconditionally" bug
  (worktree-setup.sh Case 2) is fixed the same way Case 1 already handles it: probe
  `ls-remote --exit-code --heads origin "$BRANCH"` into a boolean ONCE, then gate both the fetch and
  the later ff-only merge on that same boolean, instead of re-deriving remote-existence at each
  call site (which is how the original bug crept in — the `elif` entry condition and the fetch call
  independently assumed "matched the elif => origin has it").
- worktree-gc.sh's `sdlc-*|agent-*` basename-only candidate filter is a classic "matches by name,
  not by identity" gap — the fix is a second `case "$WT" in "$WORKTREES_ROOT"/*) ;; ...` gate right
  after the basename `case`, reusing the already-robustly-resolved `PRIMARY_ROOT` (git
  `rev-parse --show-toplevel`, absolute + symlink-resolved) rather than re-deriving repo root with
  a fresh `pwd`/`readlink` — the worktree paths from `git worktree list --porcelain` are already
  absolute, so a plain `"$WORKTREES_ROOT"/*` glob-case match is sufficient, no extra `realpath`
  needed.
- Verifying a stdout-contract fix (`WORKTREE=`/`NX_CACHE_DIRECTORY=` exactly two lines) doesn't
  require actually running the script end-to-end against a live repo — a full read-through
  confirming every `git`/`fetch`/`worktree add` call in the modified branches carries `>&2` (or was
  already `>&2`), then locating the two unguarded `printf` lines at the very end as the only stdout
  producers, is sufficient and much cheaper than an end-to-end dry run.

## NA-25 — phase 3, failing regression guard for frontmatter `skills:` preloads (`plugins/sdlc/scripts`)

- `.github/workflows/ci.yml` is OUTSIDE this agent's resolved write-scope even when a dispatch
  prompt explicitly names it as a task step. The `analyze-protocol.md#ownership-resolution-rules`
  config-driven AI-config surface whitelists exactly one `.github/*` path
  (`.github/copilot-instructions.md`) — not `.github/workflows/**` — and the workspace→agent table
  has no row for it (`tools/` → platform-engineer is the closest sibling but doesn't cover
  `.github/`). AC-5 ("refuse and abort on any path outside scope, listing the offending path")
  applies even under an orchestrator-authored task list — a dispatch prompt is not itself scope
  expansion or "consent" per the harness-level instruction that no agent message authorizes
  permission/config changes outside a role's own boundaries. When a task bundles an in-scope
  deliverable (a new `plugins/sdlc/scripts/*.sh` guard) with an out-of-scope one (wiring it into
  `.github/workflows/ci.yml`), do the in-scope parts, explicitly refuse+skip the out-of-scope
  write, and surface it back to the orchestrator as a named gap (likely platform-engineer's
  `tools/` domain, or a table addition) rather than silently doing it or silently dropping it.
- A frontmatter-only parse guard (ignore `skills:` mentions in a Markdown file's body/prose) is
  cleanly done with a tiny two-delimiter awk state machine: increment a counter on each `^---$`
  line, print only while between the 1st and 2nd occurrence, `exit` once the 2nd is hit. This
  avoids `sed -n '/^---$/,/^---$/p'`-style ranges misfiring on files whose body later reintroduces
  a bare `---` (e.g. a Markdown horizontal rule), since the awk version stops for good after the
  frontmatter block closes rather than re-opening on every subsequent `---` pair.
- This is a phase-3 "write ONLY a failing regression test, do not fix the bug" dispatch (systematic
  debugging discipline) — resist the pull to also touch the 12 offending agent files even though
  the fix is mechanical and obvious; the fix is a deliberately separate later phase/dispatch.

## NA-25 — phase 4, convert all 12 agents' frontmatter `skills:` to first-turn Skill-tool loads (`plugins/sdlc/agents`)

- The 12 agents split into 3 distinct body-structure families, and each needed a different merge
  strategy rather than one copy-pasted section: (1) the 5 domain-implementer agents
  (database-administrator, mobile-engineer, platform-engineer, sync-engineer, web-engineer) share a
  byte-identical `## Skills` section that already explained frontmatter-preload + override-skill
  ordering — extend that section in place rather than inserting a second "load FIRST" block above
  it, since the instruction to "merge into an existing skills-invocation section" outranks the
  "place prominently near the top" default when the two conflict. (2) principal-engineer,
  qa-engineer, solutions-architect, tech-lead already had a `## Required skills — invoke in order
before any other step` section, but it listed **only a subset** of the frontmatter `skills:` list
  (e.g. principal-engineer's body named 2 of 4 frontmatter skills, qa-engineer's named 3 of 6) —
  the body list must be extended to the FULL frontmatter list in frontmatter order, not left
  partial, since the removed frontmatter was the only place the omitted skills (`acli`, `gh-cli`,
  `subagent-driven-development`, `conventional-commit`) were ever declared. (3) product-manager and
  scrum-master needed the same full-list-extension treatment, plus adding `Skill` to `tools:` (both
  lacked it entirely — Read/Write/Bash or Read/Bash/Edit only). Always diff frontmatter `skills:`
  against the body's already-invoked subset before writing the merge; don't assume an existing
  "Required skills" section is already complete just because it exists.
- scrum-master's existing skills section was a **per-step invocation table** (`user-story-mapping`
  invoked at a specific point in Mode 1, `user-story-splitting` only when a story is >8 pts) — this
  answers _when to apply_ a skill, which is orthogonal to _when to load_ it. The NA-25 workaround
  needs loading to happen in the first turn regardless of when the skill is semantically applied
  later in a multi-mode agent's execution. Fix: keep the table (renamed to describe application
  timing, "loading early does not mean applying early") and prepend a numbered load-first list
  covering all 3 frontmatter skills (including `acli`, which the table never mentioned as an
  invoked skill even though it's the agent's mandatory Jira transport) — this is a genuine merge,
  not a duplicate, because the two blocks answer different questions about the same skill set.
- 6 of the 12 agents (principal-engineer, qa-engineer, solutions-architect, tech-lead,
  product-manager, scrum-master) had `tools:` lists with no `Skill` entry at all — their frontmatter
  `skills:` preload previously made an explicit `Skill`-tool call unnecessary for those skills, so
  nobody had needed to add the tool. Removing frontmatter preloads makes `Skill` load-bearing for
  every one of the 12 agents; grep `tools:.*Skill` across all agent files after any such conversion
  to catch this rather than assuming the 6 files that already had `Skill` (because they also had
  `Write`/`Edit` domain-agents needing it for a different reason) generalize to the rest.
- The regression guard (`check-agent-skill-preloads.sh`, added in phase 3) parses ONLY between the
  first two `^---$` lines, so it is blind to anything in the body — a body section that still says
  "Generic skills are preloaded via frontmatter" after the frontmatter block was actually removed
  would pass the guard while being factually wrong. The guard proves the mechanical fix; it does
  NOT prove the prose was updated to match. Manually verify every body sentence that used to
  describe frontmatter preloading (ai-enablement-engineer's First-steps item 2 had one, each of the
  5 domain-implementer agents' `## Skills` intro sentence had one) was reworded, not just removed
  frontmatter-side.
- This dispatch touches `plugins/sdlc/agents/ai-enablement-engineer.md` — the file that IS this
  agent's own definition, being edited by an instance of the same agent in the same session. No
  special handling needed (it's a normal in-scope write, and the running instance already has this
  turn's skills loaded from its own dispatch), but worth flagging for future dispatches: self-owned
  file edits still go through the identical write-scope check and Edit-tool flow as any other file.

## NA-25 — QA fix round on commit 9d6fc64 (`plugins/sdlc/agents/scrum-master.md` + `plugins/sdlc/scripts`)

- Confirmed root cause of the scrum-master.md corruption: the file's Mode-1 "Execution steps"
  numbered list uses non-standard sub-item markers (`6a.`, `10a.`, `10b.`) that are not valid
  CommonMark ordered-list syntax. `npx prettier --check` on the saved (Edit-tool) content reported
  "All files formatted correctly" — a **false negative**, exactly the trap NA-27's `e510d80` memory
  entry already flagged: the repo's real `lint-staged` pre-commit hook runs `prettier --write`
  during `git commit`, and that invocation produced a different result than my pre-commit
  `--check`. Only `git show <sha> -- <file>` after the commit reveals what actually landed — never
  trust a pre-commit `--check`/`--write` dry run as proof the committed content will match.
  Whatever upstream edit disturbs an ordered list's numbering (here: inserting new content earlier
  in the same file, unrelated to the `10a.`/`10b.` region) can trigger a full-list renumber pass by
  prettier's remark parser that then mis-parses the non-standard sub-markers as plain paragraph
  text, flattening their nested bullets and turning fenced code blocks into corrupted inline spans.
- Fix pattern (same family as `e510d80`, confirmed to generalize): dedent the ENTIRE `10a.`/`10b.`
  pseudo-list-item block — marker, prose, sub-bullets, and fences — to column 0, with blank lines
  separating prose/bullets/fences from each other. This removes ALL ambiguity about whether the
  content is "nested inside" the preceding numbered list item, so prettier's parser has nothing to
  reconcile and leaves the block untouched on every subsequent pass. Verified via a real,
  in-repo-tree `pnpm exec prettier --write` run TWICE in a row: the first pass only trimmed two
  stray leading spaces (cosmetic), the second pass reported `(unchanged)` and produced a byte-
  identical diff — that two-pass "second write is a no-op" check is the actual proof of stability,
  not a single `--check` invocation (which is exactly the false-negative trap above).
- `check-agent-skill-preloads.sh`'s original `agents_dir="$(cd "$here/../agents" && pwd)"` line is
  a classic `set -uo pipefail`-without-`-e` trap: a failed `cd` inside a command substitution does
  NOT stop the script (no `-e`), so `agents_dir` silently becomes an empty string, and the
  subsequent `for f in "$agents_dir"/*.md` glob degrades to `/*.md` (repo root) or, on an empty-but-
  existing dir, to the literal unexpanded glob string (caught by the old `[ -e "$f" ]` per-item
  skip) — both paths fall through to zero offenders and a false "OK" exit 0. Fix: check `[ -d
"$agents_dir" ]` explicitly BEFORE resolving the absolute path (so a missing dir fails loudly
  first), then use `shopt -s nullglob` + an array (`files=("$agents_dir"/*.md)`) instead of the
  bare `for f in .../*.md; do [ -e "$f" ] || continue` idiom — nullglob makes a true zero-match
  glob expand to a genuinely empty array, so `[ "${#files[@]}" -eq 0 ]` reliably distinguishes
  "no files matched" from "one file matched" without relying on the per-item existence-check
  side-effect. This same nullglob-array pattern is worth reusing anywhere else in the plugin that
  still uses the bare `for f in "$dir"/*.ext; do [ -e "$f" ] || continue` idiom to iterate a glob —
  it is silently vacuous on a missing/empty directory, not just fragile.

## NA-7 — `/gtm:docs` docs-SEO audit command + `docs-auditor` agent + rubric (`plugins/gtm`)

- `docs-auditor` is the first `plugins/gtm` agent authored under the NA-25 Skill-tool-loading
  pattern from day one (no frontmatter `skills:` list at all — `content-writer.md` and
  `product-marketing-manager.md`, both pre-NA-25, still carry frontmatter `skills:`). The spec
  said so explicitly ("both loaded via the Skill tool, per the NA-25 resume workaround — not
  relied on via frontmatter preload"), and NA-25's own memory entries document the pattern was
  only ever applied to the 12 `plugins/sdlc/agents/*.md` files, not gtm's. When a new agent's spec
  names the NA-25 pattern by name, follow the sdlc-plugin agents' shape (no `skills:` frontmatter
  field, `tools:` includes `Skill`, a body "## Required skills" section with the exact marker
  sentence) rather than copying the sibling `content-writer.md`/`product-marketing-manager.md`
  frontmatter-`skills:` shape it's dispatched alongside — the two conventions now legitimately
  coexist in the same plugin until a future story converts the older agents.
- `gh pr list --search "head:<prefix>"` (substring/ref match, confirmed by `dep-gate.sh`'s own
  comment in `plugins/sdlc/scripts/dep-gate.sh`) is exactly the right tool for a
  branch-namespace-prefix idempotency probe (`gtm/docs-audit/*`) — `--head` only does exact-match
  and can't express a prefix at all. Paired it with a documented, greppable PR-body convention —
  each finding is a dash-prefixed line whose first backtick-quoted token is the finding ID,
  followed by a second backtick-quoted rubric reference and a colon-prefixed summary — so the
  command's step-3 idempotency-guard-input enumeration and the agent's step-5 PR-authoring
  convention stay in lockstep. Defined the exact `grep -oE` pattern once in the command doc and
  cross-referenced it (not re-derived) from the agent doc's PR-body instructions.
- A spec's "so init seeds it" phrasing for a new `marketing-context-template.md` block does not
  always mean `commands/init.md` itself needs editing: this story's Config table gives the new
  `Docs audit paths`/`excludes` fields **fixed, non-interviewed defaults** (no founder decision
  point), and `init.md` Step 5 already generically "fills this template from
  `${CLAUDE_PLUGIN_ROOT}/refs/marketing-context-template.md`" — so a template-only edit (new
  section + Schema rows + a Fill rule stating "no interview, always the documented default")
  is sufficient and correctly matches the spec's own New/Modified-files table, which does NOT list
  `commands/init.md` as touched. Verified against the live repo: `.claude/project/marketing-context.md`
  in this worktree predates the story and genuinely lacks the `## Docs audit` block, which is
  exactly the "config predates this story" fallback case `/gtm:docs` step 2 is written to handle
  — confirms the fallback path is real, not speculative, and that this file itself is correctly
  out of this story's write-scope (owned by init runs, not hand-edited by a plugin-authoring story).
- Read the actual `ai-seo` and `content-strategy` marketingskills skill bodies (via the Skill tool)
  before drafting `refs/docs-audit-rubric.md` rather than inferring criteria from the skill names —
  concrete section titles/quotes from those skills (e.g. ai-seo's "40-60 word... snippet
  extraction", "Query Fan-Out", the Princeton GEO citation-boost table; content-strategy's
  "Keyword Research by Buyer Stage") became the rubric's `Source` column citations, which is what
  makes `rubricRef` genuinely traceable (AC-1) instead of a plausible-sounding invention.

## NA-25 — third review round on PR #73 (6 accepted findings: `refs/domain-agent-handoff.md`, `README.md`, all 12 `agents/*.md`, `scripts/check-agent-skill-preloads.sh`)

- A prose passage explaining a mechanism ("frontmatter-preloaded") that a PR itself just removed is
  a self-contradiction a reviewer WILL catch even when the passage isn't in a file the PR's diff
  touched directly — `domain-agent-handoff.md` and `README.md` both independently restated the old
  "frontmatter-preloaded" framing for the `Skills loaded:` omission rule, and neither got updated
  when the 12 agent files were converted in the first fix round. Same lesson as the NA-26 "one
  source of truth restated in N places" pattern: after a mechanism change, `grep -rn
'frontmatter-preload'` (or whatever the old mechanism's name was) across the WHOLE plugin, not
  just the files the task named, before declaring the conversion complete.
- A blanket "FIRST action, before any other work" instruction is too strong when the same agent
  body already has an earlier, load-bearing gate (a step-0 branch-verify STOP, or a nesting
  self-guard) that must run first and can itself early-abort with zero skills loaded — the two
  instructions read as contradictory ("load first" vs "this STOP happens before anything"). Fixed
  by softening the lead-in everywhere to name the ordering relationship explicitly: "Before any
  implementation work — after your pre-flight/step-0 checks, and skipped entirely on an early abort
  — load each of these via the Skill tool". This still satisfies the NA-25 workaround (skills load
  in the same first turn that also runs the pre-flight checks — turn granularity, not instruction
  ordinality, is what defeats the harness re-injection bug), while no longer overriding a
  higher-priority STOP gate. Reusable pattern: when adding a "must happen first" instruction to an
  agent body that might already gate on an early-abort condition, name the interaction explicitly
  rather than leaving two absolute-sounding directives to silently conflict.
- Turning a "consistent marker string for a machine-checkable guard" requirement into an actual
  fix meant treating the marker sentence as a literal contract, not just matching prose: I wrote
  the exact same sentence (`Before any implementation work — ... — load each of these via the Skill
tool:`) into all 12 files, including the 5 "Shape B" agents whose skill list was originally
  written as inline comma-separated prose rather than a numbered list — for those, the marker
  sentence had to end in a colon immediately followed by the backtick-quoted skill list on the SAME
  physical line (not wrapped), since a guard doing `grep -F` needs the literal substring intact on
  one line. Confirmed via `grep -qF "$marker" "$f"` in a real test loop across all 12, and confirmed
  prettier's default `proseWrap` (unset in this repo's `.prettierrc` → "preserve") does not
  re-wrap long unwrapped lines, so writing the marker as one long physical line is stable across a
  real `prettier --write`.
- A regression guard that only checks a NEGATIVE condition ("no frontmatter skills:") can still be
  vacuously satisfied by a file that was simply stripped of frontmatter without ever gaining the
  intended replacement (e.g. someone deletes the `skills:` block but never adds a first-turn load
  section). Pairing it with a POSITIVE check (the file must also contain the load marker) closes
  that gap — test both directions separately in a scratch temp-dir copy (never the real tree): (1)
  delete the marker line from one file → guard must fail on marker-missing; (2) re-add a
  frontmatter `skills:` block to a different file → guard must fail on preload, and can report BOTH
  failure classes together in one run without the second masking the first (used two independent
  offender-accumulator variables + a shared `fail` flag rather than one `exit 1` per check).
- The awk frontmatter-extractor's original 2-delimiter counter had no anchor on the OPENING `---` to
  `NR==1` — a frontmatter-less file whose BODY happens to contain two `---` horizontal-rule lines
  with something matching `^skills:` between them would false-positive, since the awk state machine
  treats the FIRST `---` it sees anywhere in the file as the opener. Fix: split into `NR==1 &&
/^---$/ { open=1; next }` / `NR==1 { exit }` (no frontmatter at all if line 1 isn't the delimiter)
  / `open && /^---$/ { exit }` (closing delimiter) / `open { print }`. Verified with a crafted
  scratch file (no real frontmatter, plain body containing a `---`/`skills:.../---` span) that the
  old unanchored version would have flagged and the anchored version correctly passes.
- Scrum-master's step-10 continuation block (blockquote + fenced bash + bullet list) was indented 8
  spaces under a 4-char `10. ` marker — one indent level too deep for CommonMark list-continuation
  (needs exactly 4, matching the marker width), so it rendered as a literal indented code block
  rather than list-item content. This was PRE-EXISTING content the first two NA-25 fix rounds never
  touched (round 1 only edited the "Required skills" section near the top; round 2 fixed 10a/10b's
  separately-corrupted fences but left step 10's own body alone) — a reviewer eventually caught it
  on a fresh pass over the whole file, not from a diff. Applied the SAME column-0-dedent pattern
  already established for 10a/10b (`61f217f`) rather than trying 4-space re-indentation, for
  consistency and because it's the pattern already proven prettier-stable in this exact file.
  Verified via the same two-pass `prettier --write` idempotence check (both passes report
  `(unchanged)`) plus the `grep -c '```'` = 24 fence-count invariant.

## NA-44 — `writing-adrs` skill, ships ahead of its own consumer (`plugins/sdlc/skills`)

- This story deliberately ships a plugin-bundled skill (`writing-adrs`) with zero live consumer:
  the knowledge-engineer agent and `/sdlc:adr` command that will invoke it are a separate,
  not-yet-implemented story (NA-43). AC-5 still requires documenting the exact `agents:` /
  `source-stories:` ADR-frontmatter contract the future pipeline will read, so the skill had to
  be written from the _planned_ contract description in the dispatch prompt, not from any
  existing code to cross-check against — verified there was nothing under `plugins/sdlc/agents/`
  or `plugins/sdlc/commands/` yet named `adr`/`knowledge-engineer` before writing, so the skill's
  routing-field prose is the first and only place that contract exists on disk right now.
- Distinguishing "this SKILL.md's own frontmatter" (name+description, controls Claude's skill
  triggering) from "the frontmatter a _generated ADR document_ carries" (status/agents/
  source-stories, read by a future pipeline) needed an explicit callout sentence
  ("This is distinct from this SKILL.md's own frontmatter above...") — both are YAML frontmatter
  blocks in the same file, one describing the skill itself and one being a worked/templated
  example of a _different_ file's frontmatter, and without the callout a reader skimming past the
  second `---...---` block could easily conflate the two.
- Kept the one required worked example deliberately framework/stack-agnostic (a generic
  "PostgreSQL as primary datastore" decision) rather than reaching for this repo's own real stack
  choices (e.g. Payload/Neon from the marketing-site memory) — `plugins/` ships as a public,
  install-anywhere artifact per the existing published-skills rule, and a worked example tied to
  nightshift's own infra would read as this-repo-specific inside a generic authoring skill, even
  though nothing in `portability-lint.sh`'s actual checks (absolute paths/emails/frontmatter/
  JSON/skill-structure) would have caught that as a violation — it's a stylistic generality
  concern the lint doesn't enforce, not a lint failure.
- Fetched both canonical sources in full before writing (Fowler's 2026 `ArchitectureDecisionRecord`
  bliki entry, and Nygard's original 2011 Cognitect post, both reachable via plain `curl -sL`,
  stripped to text with a small inline Python `re.sub('<[^>]+>', ...)` pass rather than any
  fetch/index MCP tool — this session's actual tool list only exposed Read/Write/Edit/Bash/Skill,
  no context-mode MCP functions were actually callable despite the dispatch prompt's context-mode
  tool-preference banner, so Bash `curl` was the only usable option and is explicitly what the
  task's own instructions asked for). Fowler's confidence/uncertainty-honesty framing and the
  "forces" borrowing from pattern-writing came from his piece; Nygard's exact five-part format
  (Title/Context/Decision/Status/Consequences) and the "written as a conversation with a future
  developer, full sentences not bullet fragments" discipline came from his. Cross-checking both
  against the dispatch's distilled-canon bullets surfaced no contradictions, only Nygard's
  original three-status set (proposed/accepted/deprecated-or-superseded) which the distilled canon
  and Fowler's later piece both simplify to proposed/accepted/superseded — used the
  simplified/canonical three-state set since that's what both the dispatch AC and Fowler's own
  "further developments" framing settled on.

## NA-43 — `knowledge-engineer` agent + `/sdlc:adr` command (`plugins/sdlc`, consumes NA-44's `writing-adrs` skill)

- A spec's assumed MCP tool slug can be wrong even when the tool BASE names (`observation_search`,
  `get_observations`) are right — the merged spec assumed `mcp__claude-mem__*`, but the installed
  `claude-mem` plugin registers its MCP server as `mcp-search`, not `claude-mem`. The plan (and the
  dispatch prompt that carried it forward) had already corrected this with a concrete,
  session-verified fully-qualified name (`mcp__plugin_claude-mem_mcp-search__observation_search` /
  `__get_observations` — the plugin-installed form) rather than leaving it as an open question to
  re-derive at implementation time. When a grounding correction hands you an already-verified
  literal, use it verbatim in agent frontmatter `tools:` rather than re-deriving or second-guessing
  it from static docs — this session's own tool list had no way to independently confirm an MCP
  server slug (no claude-mem tools were present to introspect), so the orchestrator-supplied,
  live-session-verified value was the only trustworthy source of truth available.
- Adding a second sanctioned cross-agent-memory-write exception to `analyze-protocol.md` required
  promoting the previously-implicit single exception (referenced only as "the human-arbitrated
  memory-conflict reset" inline in two places — the read-only-carve-out bullet and the
  memory-conflict-resolution step) into a first-class named `## Memory-ownership exceptions`
  section with both exceptions enumerated, then updating both original inline mentions to point at
  it instead of restating the rule. This is the same "one source of truth + pointers" pattern from
  NA-26 — creating Exception 2 without first extracting Exception 1 into the same anchor would have
  left the "exactly one exception" framing contradicted by a second exception documented somewhere
  else, which a reviewer would catch as an internal inconsistency.
- The five domain-implementer agents (`database-administrator`, `platform-engineer`,
  `sync-engineer`, `web-engineer`, `mobile-engineer`) are still byte-identical to each other
  (confirmed via `diff` before editing, same as the NA-25 family-split lesson) — but `web-engineer`
  is ALSO byte-identical to them now (an earlier memory entry only diffed the first four against
  each other). Editing the shared "Read your memory archives" line required six near-identical
  edits (five domain agents each with their own agent-name interpolated into the new sentence, plus
  a differently-worded sixth for `ai-enablement-engineer.md` whose First-steps section already had
  extra prose around it) rather than one shared edit — there is no ref file backing this literal
  sentence the way `domain-agent-handoff.md` backs the branch/memory/commit protocol, so the
  duplication is structural to the current agent-file design, not an oversight to "fix" in this
  story.
- `qa-engineer.md`'s ADR read-path could NOT go in the same spot as the six domain agents (a
  numbered "First steps" step 3) because that file has no such numbered list at all — its
  equivalent section is a prose "## Read project context first" bullet list. The plan's own task
  text anticipated this ("~L59 and/or the Learn loop step ~L113-114") but the actual file (132
  lines total) has no line 113-114 region matching that description — the QA playbook (a separate,
  much longer file) is where the "Learn" step with `patterns.md` lives, not the agent file itself.
  Read the actual target file's structure before trusting a plan's approximate line-range citation
  when the plan was written from the spec's prose rather than a byte-level line count.
  Cross-checked instead against the file's real structure and added the ADR read as a new paragraph
  after the existing bullet list in "Read project context first," with an explicit sentence tying
  it to Step 5 of the (separate) `qa-engineer-playbook.md` so a reader understands why QA specifically
  needs this read-path (distill can promote-and-delete `patterns.md` entries).
- Confirmed (again) that this repo's real `lint-staged`/`prettier --write` pre-commit hook silently
  reflows every Markdown table this story touched (column-width realignment across
  `adr-pipeline.md`, `adr.md`, `analyze-protocol.md`) on every commit — never trust the
  pre-Edit-tool draft as the final committed byte content; the post-commit `git status --short`
  empty check plus a targeted `grep`/verify-command re-run against the actual committed tree (not
  the pre-commit draft) is what actually proves the fix landed, consistent with the NA-25/NA-27
  "pre-commit `--check`/`--write` dry run never proves what actually lands" lesson family. All of
  this story's own Task-level verify greps were re-run against the post-commit tree and passed.

## 2026-07-15 — Story NA-44 — review fix

**Learnings:**

- When authoring skills that autonomous agents apply mechanically, every rule must resolve deterministically: state the rule, then the single explicit exception with its boundary — never hedge both into one sentence.
- Shipping any new content under plugins/<plugin>/ requires bumping that plugin's .claude-plugin/plugin.json version in the same PR (plugins/ is a published artifact; pinned consumers won't see unversioned additions).

**Pitfalls:**

- "This rule holds even for X — unless truly cosmetic" phrasing reads as contradiction when X is itself cosmetic; reviewers will (correctly) block on it.

## 2026-07-15 — Story NA-44 — review fix, round 2 (PR #106, in-session /code-review + Copilot)

- A skill authored for a pipeline that hasn't shipped yet (`/sdlc:adr` + knowledge-engineer, NA-43
  pending) needs "not yet shipped" framing repeated at every place the pipeline is named, not just
  the first — round 1 didn't get flagged for this because the skill correctly stood alone as an
  authoring standard, but round 2's reviewer read four separate mentions of `/sdlc:adr` and
  `knowledge-engineer` as claims the pipeline already existed. Fix pattern: state "upcoming/not yet
  shipped" once where the entity is first introduced, then keep every subsequent mention
  consistent with that framing (e.g. "once it exists", "where the pipeline is installed and in
  use") rather than dropping back to bare present-tense phrasing on later mentions of the same
  not-yet-real thing.
- A per-agent index-generation contract with no explicit unrouted-item rule is an easy latent drop:
  an ADR with `agents: []` (or the field omitted) has nowhere to go in a "one section per named
  agent" grouping scheme unless a fallback bucket is named explicitly. Fixed by adding a `General`
  (unrouted) section to the index contract — the generalizable check is "does every classification/
  grouping rule in a skill or ref have an explicit branch for the empty/omitted case," since an
  implicit "and if it has none, ???" is exactly the kind of gap a reviewer (or a future
  implementer) will hit on the very first real edge-case record.

## 2026-07-16 — Story NA-43 — review fix

**Learnings:**

- When authoring a lifecycle (status enum) into pipeline docs, define the transition event for every edge — a guard keyed on a status that nothing ever sets is silently inert.
- Guidance warning against a specific token must describe it, never quote it literally — the literal trips future grep/denylist scans.

**Pitfalls:**

- Command mode tables covering only disjoint flag cases leave combined inputs (flag + free text) implementation-defined; add a row or an explicit STOP.

## 2026-07-17 — Story NA-52 — `/sdlc:docs sync` command + `refs/docs-pipeline.md`

- A "registry self-check" grep gate across multiple files (here: `doc-types.md` +
  `docs-pipeline.md` + `docs.md` all restating the same `llms-txt` `source-of-truth` string
  verbatim) breaks silently when prettier reflows one of the restatements across a Markdown line
  wrap — the phrase was present and byte-correct in the source, but split mid-string across two
  lines by prose wrapping, so a single-line `grep -n "<phrase>"` reported only 2/3 files instead of
  3/3 until the sentence was restructured to keep the exact phrase on one physical line. Any
  cross-file verbatim-string verification gate needs the asserted string kept on one line at every
  restatement site, not just written correctly — re-run the grep after `prettier --write`, not
  before, since prettier is what can introduce the wrap.
- Extending an existing dual-purpose agent (`knowledge-engineer`, already serving `/sdlc:adr`) with
  a second, structurally-parallel pipeline is a "branch every shared section, don't add a global
  one" exercise: the required-skills list, the `Skills loaded:` return-line contract, and the
  Pipeline section all needed the same shape — one bullet/paragraph per dispatch type, explicit
  that each type's skill set must NOT include the other type's skill (`writing-adrs` vs
  `writing-docs`) — rather than a single merged list with a footnote. Mirrors the NA-43/NA-44
  memory-conflict-exception pattern (promote the shared concept to a named, enumerated split point)
  but applied to agent dispatch-type branching instead of memory-write exceptions.
- `refs/docs-pipeline.md` mirrors `refs/adr-pipeline.md`'s two-phase-dispatch skeleton almost
  exactly (phase 1 writes nothing and returns; founder-confirm gate lives at the command layer;
  phase 2 is a fresh dispatch that writes only what it was handed verbatim) — but the _branch cut
  point_ differs in a way worth calling out explicitly rather than leaving implicit: ADR branches
  cut from `<BASE-BRANCH>` (a brand-new decision record has no source-of-truth dependency on any
  other branch's tree), while docs-sync branches cut from the **story branch head**, because the
  deterministic regen algorithm reads the changed source files themselves — branching off base
  would regenerate from a tree that's missing the very changes the sync is supposed to reflect.
  When mirroring a pipeline skeleton for a new command, check whether the new command's write step
  actually needs to read repo state the base branch wouldn't contain before copying the base-branch
  cut-point verbatim.
- The plan's Task 5 Step 4 said "Error Handling table verbatim from the spec (nine scenarios)" but
  the spec's actual table has eleven rows — trusted the spec (the binding contract, explicitly
  named as such in the dispatch prompt) over the plan's parenthetical count and copied all eleven
  rows verbatim rather than trimming to match the plan's stated count. When a plan's descriptive
  aside about a spec artifact (a row count, a section count) conflicts with the spec itself, the
  spec wins — the aside is likely just an inaccurate paraphrase, not a scope instruction to drop
  rows.
- `skill-creator`'s `scripts/quick_validate.py` lives inside _this repo's_ installed
  `plugins/sdlc/skills/skill-creator/` tree (not a separate globally-cached plugin location) —
  running it against an edited skill is `python3 plugins/sdlc/skills/skill-creator/scripts/quick_validate.py plugins/sdlc/skills/<name>`
  from the repo root. Useful to know for any future skill edit needing the "run quick_validate"
  verification step without re-deriving where the script lives.

## 2026-07-17 — Story NA-52 — QA round 1 fix

- The first-pass "branch every shared section" work on `knowledge-engineer.md` (see the entry
  above) still missed two sections that needed the same ADR-vs-docs-sync split: "Branch, memory,
  commit, return" and the "Completion checklist" — both still read as ADR-only prose (the branch
  section's step 1 literally said "off `<BASE-BRANCH>`", directly contradicting
  `docs-pipeline.md` §7's story-branch-head cut point for docs-sync). A "branch every shared
  section" sweep needs to be a literal grep for every `##`/`###` heading in the file, not a
  from-memory list of "the sections I already knew needed it" — the two I'd already branched
  (required-skills, `Skills loaded:` return line, Pipeline) were the ones explicitly named in the
  dispatch prompt's task steps; the two QA caught were downstream sections whose ADR-only content
  only became wrong _because_ of the upstream branching, not sections the original task list named.
- `git diff --name-only "<BASE-BRANCH>...$STORY_BRANCH"` (bare local branch name on the left side
  of a three-dot range) is checkout-dependent in a way that's easy to miss when writing the
  contract from the spec's own bash snippet — the spec's own example used the bare form. QA's fix
  was `origin/<BASE-BRANCH>...$STORY_BRANCH` (remote-tracking on both sides) since `sync` already
  fetches (`git fetch origin --quiet`) before resolving `STORY_BRANCH` as an `origin/*` ref — using
  a bare local base ref right after that fetch is inconsistent (one side of the diff is guaranteed
  fresh, the other isn't) and silently wrong if the invoking checkout's local `<BASE-BRANCH>` is
  stale. When a spec's own worked bash example mixes a fetched remote ref with a bare local one in
  the same diff command, don't copy it verbatim — normalize both sides to the same freshness
  guarantee.
- Prettier's per-file reflow can shift a fix's target line numbers between "what I read" and "what
  actually gets committed" (table column realignment shifted `doc-types.md`'s Registry rows table
  by one line after the `source-of-truth` schema-cell edit). Re-read line numbers from a Read call
  after any earlier edit in the same file before doing a second targeted edit later in the same
  session, rather than trusting line numbers cited in a review finding against the pre-prettier
  draft.
