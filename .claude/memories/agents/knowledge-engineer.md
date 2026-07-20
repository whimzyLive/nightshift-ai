# knowledge-engineer memory

## `/sdlc:docs audit` — 2026-07-20 (first run, `docs/audit-2026-07-20`, PR #152)

- **Registry path patterns aren't literally repo-root in this repo.** `refs/doc-types.md`'s
  `command-reference`/`agent-reference` rows say `commands/**`/`agents/**`, and
  `config-reference` says `refs/*-template.md` — nightshift-ai has none of those at the
  repo root (only a single mirrored `agents/ci-monitor-subagent.md`). This repo's real
  command/agent/config-template source lives under `plugins/{sdlc,gtm}/commands/**`,
  `plugins/{sdlc,gtm}/agents/**`, and `plugins/sdlc/refs/*-template.md` — because
  nightshift-ai _is_ the sdlc/gtm plugins' own home repo, and its public docs
  (`docs/how-to`, `docs/tutorials`, `docs/concepts`) already document those two plugins'
  commands/agents specifically. Resolved by treating the registry's bare path patterns
  as matching **anywhere** in the tree (same spirit as `skill-reference`'s explicit
  `**/SKILL.md`), not literally root-only. Re-verify this call if the repo ever gains a
  real top-level `commands/`/`agents/` dir of its own.

- **Frontmatter parsing: neither a naive regex-per-line parser nor strict YAML
  (`yaml.safe_load`) works on this corpus.** A hand-rolled parser that only special-cased
  `>-`/`|` block scalars silently **truncated** plain (bare, no block indicator)
  multi-line descriptions at the first physical line (e.g.
  `.agents/skills/vercel-composition-patterns/SKILL.md`). Switching to strict
  `yaml.safe_load` then broke on a _different_, equally real pattern: several command
  descriptions contain an unquoted, unescaped, mid-sentence colon (e.g. `...suggested
next step: the sdlc plugin.` in `plugins/gtm/commands/site.md`), which YAML parses as
  a new mapping key and throws `ScannerError`. The fix that actually works: a
  **column-0 key-boundary scanner** — a line matching `^key:` at column 0 starts a
  field; every following blank-or-indented line is appended as continuation (raw text,
  never re-parsed as YAML) until the next column-0 key or the closing `---`. This
  tolerates embedded colons in continuation text (they're never at column 0) while
  still capturing plain multi-line scalars in full. See
  `docs/reference/*/*.md` generation script pattern if resurrecting this for `sync`.

- **`glob.glob("**/SKILL.md", recursive=True)`silently skips dot-directories.** It
missed 18 of this repo's 47 tracked`SKILL.md` files (`.agents/`, `.claude/`,
`.github/`, `.opencode/`skill mirrors) with no error — first found via a suspicious
page-count drop (33 → 29 after the frontmatter-parser fix, when it should have gone
up). Use`git ls-tree -r --name-only HEAD`(or the relevant base ref) as the file
enumeration ground truth instead of any filesystem walk/glob — it's also immune to`node_modules/\*\*`vendor noise (e.g.`playwright-core`ships its own`SKILL.md`,
which `os.walk(".")` happily picked up and a plain glob wouldn't have caught either).

- **Skill-reference dedup call:** of 47 tracked `SKILL.md` files, only 33 are unique by
  frontmatter `name` — 14 are byte-for-byte tool-ecosystem mirrors (`.github/skills/**`,
  `.opencode/skills/**` each duplicate 7 skills already canonical under `skills/**`).
  Generated **one page per unique name** (canonical source path + "Also mirrored at"
  list), not one page per file — one-page-per-file would have put duplicate public
  reference pages in `docs/reference/skills/` for content that's identical across
  mirrors. `command-reference`/`agent-reference` had no such collisions (no duplicate
  command/agent names across `plugins/sdlc/` and `plugins/gtm/`), so this dedup step is
  skill-reference-specific.

- **Verify audit's `auto`-row output against the real committed tree, not a redundant
  local re-run.** This repo's `lint-staged` pre-commit hook runs `prettier --write` at
  commit time (matches `docs/adr/0002`'s warning, generalized beyond
  `plugins/sdlc/**`) — it normalizes frontmatter to single-quoted strings and escapes
  bare `*`/`**` in prose (both cosmetic/meaning-preserving here, not corruption). A
  second, independent `npx prettier --write` run against a **copy of the output placed
  outside the repo tree** (`/tmp/...`) produced a spuriously different, badly reflowed
  result for one file with an embedded ` ```typescript ` fence — almost certainly a
  config/plugin-resolution artifact of running outside the project root, **not** a real
  determinism problem. The trustworthy check is always `git show HEAD:<path>` after the
  real commit (direct content inspection: head/tail match source, fence-parity count
  even, table pipe-counts sane) — never a second ad-hoc prettier invocation elsewhere.

- **`docs/reference/` did not exist in this repo before this run.** First audit
  backfilled all 7 `auto` rows from scratch (72 files: 18 commands, 17 agents, 33
  skills, 1 config, 1 hooks, 1 errors, + `llms.txt`). `hooks-contract` correctly reports
  "no hooks configured" (`.claude/settings.json` has no `hooks` key) rather than
  omitting the page. `error-reference` found exactly 2 genuine `## Error handling`
  sections (`plugins/sdlc/refs/analyze-protocol.md#error-handling`,
  `plugins/gtm/agents/docs-auditor.md#error-handling`) — a third heading match in
  `plugins/sdlc/agents/solutions-architect.md` is spec-template placeholder prose
  (`[What fails gracefully vs blocks the user]`), not a real table, and was correctly
  excluded (would have fabricated a fake entry otherwise).

- **Reference-integrity tier found exactly one flag:**
  `docs/concepts/what-is-the-sdlc-plugin.md` backtick-references `refs/triage.md`,
  which doesn't exist at repo root — the real file is `plugins/sdlc/refs/triage.md`.
  Flagged per §22's dangling-code-reference check, never auto-corrected (narrative
  rows are never rewritten by audit).
