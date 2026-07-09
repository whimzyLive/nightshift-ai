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
- Plugin sources live in plugins/ (sdlc, gtm) — repo IS the plugin source; installed versions resolve from the plugin cache via .claude/.*-plugin-root markers (read-only pointers).

## Local dev (tokens from project-context Tooling)
- Typecheck: none configured · Test: `pnpm nx run-many -t test`
- Never run cloud deploys — those are manual ops actions outside agent scope.
