# AI Workflow Manager — nightshift-ai bindings

## Skills (plugin-bundled — invoke via the Skill tool)

1. skill-creator
2. find-skills
3. conventional-commit

## Directory guides (read before coding)

# No directory guides yet — add CLAUDE.md files to owned paths.

## Ownership

- owns: plugins/, skills/, .agents/, .claude/, CLAUDE.md, AGENT.md/AGENTS.md and the AI-config surface (baseline globs ship in the agent definition; this override may add more)
- never: .claude/project/project-context.md, .claude/.\*-plugin-root pointers, other agents' memory files
- runs after: — · before: —

## Tech rules

- No informative/explanatory comments — see the shared rule at
  `${CLAUDE_PLUGIN_ROOT}/refs/code-comments-policy.md` (excludes comments required by language or
  lint conventions).
- Markdown/Shell; kebab-case file naming; any shell script touched must pass `bash tools/portability-lint.sh` (gate present in this repo).
- Skill layout (three tiers — do not mix):
  - `.agents/skills/<name>/` — installed by the skills CLI (`npx skills add <owner/repo>`), pinned in root `skills-lock.json`. Never hand-edit content or the lockfile; update via `npx skills update`.
  - `.claude/skills/<name>` — discovery surface for Claude Code: a symlink `→ ../../.agents/skills/<name>` for CLI-installed skills, or a real directory for local hand-authored skills (e.g. nightshift-design).
  - `skills/<name>/` — workspace-authored skills committed to the repo (nx-\*, hono-api, …).
- Keep the sync trio aligned when adding/removing a skill: install location, `.claude/project/skills.json` entry, and the relevant agent override's skill list.
- Sync-trio exemptions (by design, not drift): nx-native workspace skills (`skills/nx-*`, `monitor-ci`, `link-workspace-packages`) are driven by the auto-managed nx block in root CLAUDE.md/AGENTS.md and self-triggering frontmatter — they are not tracked in skills.json or overrides.
- **`plugins/` and `skills/` are PUBLISHED artifacts** — this repo hosts them as public skills/plugins for others to consume. Presence on disk does NOT imply this project uses them (e.g. skills/hono-api, skills/typeorm, skills/electrodb have no matching deps here). Never delete or "clean up" entries under plugins/ or skills/ because they look unused locally.
- Plugin sources live in plugins/ (sdlc, gtm) — repo IS the plugin source; installed versions resolve from the plugin cache via .claude/.\*-plugin-root markers (read-only pointers).
- nx marketplace plugin generates cross-tool AI-config mirrors (agents/, .codex/, .opencode/, .gemini/, opencode.json) from the monitor-ci skill — machine-maintained, do not hand-edit.
- **Never hand-bump a plugin `version`** in `plugins/sdlc/.claude-plugin/plugin.json` or `plugins/gtm/.claude-plugin/plugin.json` inside any feature/impl/fix PR — leave it exactly at develop's value. Versioning is owned by nx-release (`nx.json` `plugins` group: `specifierSource: conventional-commits`, `currentVersionResolver: git-tag`, `versionActions: tools/nx-release/plugin-json-version-actions.ts`). The bump is computed post-merge by `pnpm nx release version -p sdlc` (or the `plugins` group / `pnpm nx release` for version + CHANGELOG + GitHub release) from commits since the last `{projectName}@{version}` tag. A manual edit fights nx (wrong number, tag mismatch, dirty diff) and is a defect.

## Local dev (tokens from project-context Tooling)

- Typecheck: none configured · Test: `pnpm nx run-many -t test`
- Never run cloud deploys — those are manual ops actions outside agent scope.
