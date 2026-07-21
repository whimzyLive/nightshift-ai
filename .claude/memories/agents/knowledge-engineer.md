# knowledge-engineer memory

## Audit dispatch — 2026-07-21 (docs/audit-2026-07-21, PR #155)

- **Skill-reference dedup rule (not spelled out in docs-pipeline.md).** This repo carries three
  byte-identical mirrors of 7 skills (`link-workspace-packages`, `monitor-ci`, `nx-generate`,
  `nx-import`, `nx-plugins`, `nx-run-tasks`, `nx-workspace`) under `skills/`, `.github/skills/`,
  and `.opencode/skills/` — the latter two are nx-generated machine-maintained mirrors (per
  `project-context.md`'s ownership table). `skill-reference`'s "one page per `**/SKILL.md`" rule
  would naively triple-generate these. Resolved by deduping on the skill's `name:` frontmatter key,
  preferring the canonical non-mirror source (`skills/<name>/SKILL.md` for these 7) — this matches
  PR #152's prior (if otherwise-flawed) one-page-per-name precedent. Verified byte-identity via
  `diff` before trusting this shortcut; don't assume — check.
- **`llms-txt`'s own row-disable rule bites during audit too, not just release/seed.** The
  `changelog` row was flipped to `enabled: false` in a prior commit (9e1ca70) that kept
  `docs/changelog/index.md` on disk as a hand-maintained pointer page. §8's algorithm ("generated
  pages of every ENABLED public:yes row") means that page must drop out of `llms.txt` even though
  the file itself still exists and is still linked from elsewhere — disabled-row exclusion is
  about the manifest state, not file existence. Caught this by diffing the manifest's `enabled`
  column against what the _existing_ `llms.txt` still listed.
- **Error-reference real-vs-stub test: trust the letter, not vibes.** Three files carried
  "## Error Handling" headings that were pure deferrals/placeholders (`ai-enablement-engineer.md`,
  `analyze.md` — both defer to `analyze-protocol.md#error-handling` with zero rows of their own;
  `solutions-architect.md` — literal unfilled `[What fails gracefully vs blocks the user]`
  template text). A file that has ITS OWN concrete rows counts as real even if it _also_ says
  "this mirrors the spec" or partially defers elsewhere for OTHER content (e.g.
  `gtm/commands/docs.md` has 3 own rows + a deferral note for docs-auditor's separate table — the
  3 own rows still aggregate). Don't over-index on hedge language in a trailing sentence; check
  whether the table itself has rows.
- **Byte-fidelity via shell, not manual retyping, for large mechanical copies.** For a
  first-time backfill of 70 reference pages (~18k source lines across commands/agents/skills),
  hand-retyping body content via Read+Write risks transcription drift, which directly
  contradicts the "auto" tier's byte-reproducibility requirement. Used heredoc-driven bash
  scripts (`D=$(cat <<'EOF' ... EOF)`) to inject hand-sanitized frontmatter descriptions while
  mechanically `awk`/`sed`-copying verbatim body content straight from source files. Kept the
  generator scripts in the session scratchpad so a re-run is trivially re-executable for the
  idempotence check.
- **Bash gotcha: `'...'` YAML-doubling only works inside heredocs, not bash single-quoted string
  literals.** `D='repo''s'` in a plain bash assignment does NOT yield `repo''s` — adjacent
  single-quoted segments just concatenate with nothing between them, silently DROPPING the
  apostrophe. Only `<<'EOF' ... repo''s ... EOF` (heredoc body, no bash quote parsing at all)
  preserves the literal `''`. Caught this only by validating with `yaml.safe_load` + apostrophe
  counts, not by eyeballing.
- **`read -r -d '' VAR <<'EOF'` embeds a trailing `\n` that `VAR=$(cat <<'EOF' ... EOF)` strips.**
  First pass on the 18 command pages used the `read -d ''` form, which left a stray trailing
  newline inside every command page's YAML description (valid YAML — parses fine — but wrecked
  `llms.txt`'s one-line-per-entry format when that description was echoed into a `title — desc —
link` line). Switched every generator to the `$(cat <<'EOF' ... EOF)` command-substitution form,
  which strips the trailing newline. Re-validate `llms.txt` line-by-line field count (split on
  `—`, expect exactly 3 fields) after any regen — this is the fast way to catch the class of bug.

## Audit re-run — 2026-07-21 (docs/audit-2026-07-21, PR #155, second commit)

- **`docs-pipeline.md` §3 steps 1–2 changed mid-flight: `command-reference`/`agent-reference` went
  from full-body-copy to frontmatter-only + Source link.** Re-ran the deterministic regen for all
  18 command pages and all 16 agent pages under the new shape (H1 → one-line purpose from
  `description:` → Tools from `tools:` when present, agent-only → Source link + "authoritative for
  full behavior" note). No `argument-hint:`/`allowed-tools:` exists on any command frontmatter in
  this repo today, and no `triggers:`/`invoked-by:` exists on any agent frontmatter, so every
  Usage/Triggers section is correctly omitted, not merely empty — verified by grepping the raw
  source frontmatter blocks before assuming absence.
- **Before re-deriving 34 pages' title/description, diffed `origin/develop` against the branch's
  own merge-base scoped to `plugins/sdlc/**`+`plugins/gtm/**` first.** Only 3 files had moved
  since the branch was cut (`commands/docs.md`, `refs/doc-types.md`, `refs/docs-pipeline.md`), and
  a targeted `git diff -- <file> | grep '^[+-](name|description|tools):'` on `commands/docs.md`
  and the 5 NA-48-touched agent files confirmed zero frontmatter-field drift — every change was
  body-only. That let the already-published pages' `title:`/`description:` be reused verbatim
  (byte-checked) instead of re-parsing every source file's frontmatter from scratch, and confirmed
  `llms.txt` needed no regen this run (same page set, same frontmatter, same links — verified by
  grepping two representative existing entries against the unchanged descriptions rather than
  re-deriving and diffing 78 lines). Also confirmed no `docs/adr/**` or how-to `source:`-globbed
  file changed since the branch cut, so the reference-integrity flag set (the one known
  `docs/concepts/what-is-the-sdlc-plugin.md` → `refs/triage.md` dangling ref, owned separately by
  PR #153) carries forward unchanged rather than needing a fresh anchor scan. This scoped-diff
  technique is generally reusable: on a same-day audit re-run, diff the branch's own merge-base
  against the current base ref first — it tells you exactly which of the 7 `auto` rows' inputs
  could possibly have moved, before spending effort re-deriving all of them.
