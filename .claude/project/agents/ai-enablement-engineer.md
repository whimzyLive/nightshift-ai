# AI Workflow Manager — nightshift-ai bindings

## Skills (plugin-bundled — invoke via the Skill tool)
1. skill-creator
2. find-skills
3. conventional-commit

## Directory guides (read before coding)
# No directory guides yet — add CLAUDE.md files to owned paths.

## Ownership
- owns: plugins/, skills/, .agents/, .claude/, CLAUDE.md, AGENT.md/AGENTS.md and the AI-config surface (baseline globs ship in the agent definition; this override may add more)
- never: .claude/project/project-context.md, .claude/.*-plugin-root pointers, other agents' memory files
- runs after: — · before: —

## Tech rules
- Markdown/Shell; kebab-case file naming; any shell script touched must pass `bash tools/portability-lint.sh` (gate present in this repo).
- Skill layout (three tiers — do not mix):
  - `.agents/skills/<name>/` — installed by the skills CLI (`npx skills add <owner/repo>`), pinned in root `skills-lock.json`. Never hand-edit content or the lockfile; update via `npx skills update`.
  - `.claude/skills/<name>` — discovery surface for Claude Code: a symlink `→ ../../.agents/skills/<name>` for CLI-installed skills, or a real directory for local hand-authored skills (e.g. nightshift-design).
  - `skills/<name>/` — workspace-authored skills committed to the repo (nx-*, hono-api, …).
- Keep the sync trio aligned when adding/removing a skill: install location, `.claude/project/skills.json` entry, and the relevant agent override's skill list.
- Sync-trio exemptions (by design, not drift): nx-native workspace skills (`skills/nx-*`, `monitor-ci`, `link-workspace-packages`) are driven by the auto-managed nx block in root CLAUDE.md/AGENTS.md and self-triggering frontmatter — they are not tracked in skills.json or overrides.
- **`plugins/` and `skills/` are PUBLISHED artifacts** — this repo hosts them as public skills/plugins for others to consume. Presence on disk does NOT imply this project uses them (e.g. skills/hono-api, skills/typeorm, skills/electrodb have no matching deps here). Never delete or "clean up" entries under plugins/ or skills/ because they look unused locally.
- Plugin sources live in plugins/ (sdlc, gtm) — repo IS the plugin source; installed versions resolve from the plugin cache via .claude/.*-plugin-root markers (read-only pointers).
- nx marketplace plugin generates cross-tool AI-config mirrors (agents/, .codex/, .opencode/, .gemini/, opencode.json) from the monitor-ci skill — machine-maintained, do not hand-edit.

## Local dev (tokens from project-context Tooling)
- Typecheck: none configured · Test: `pnpm nx run-many -t test`
- Never run cloud deploys — those are manual ops actions outside agent scope.
