# AI Workflow Manager — nightshift-ai bindings

## Skills (plugin-bundled — invoke via the Skill tool)
1. skill-creator
2. find-skills
3. conventional-commit

## Directory guides (read before coding)
# No directory guides yet — add CLAUDE.md files to owned paths.

## Ownership
- owns: plugins/, skills/, .claude/, CLAUDE.md, AGENT.md/AGENTS.md and the AI-config surface (baseline globs ship in the agent definition; this override may add more)
- never: .claude/project/project-context.md, .claude/.*-plugin-root pointers, other agents' memory files
- runs after: — · before: —

## Tech rules
- Markdown/Shell; kebab-case file naming; any shell script touched must pass `bash tools/portability-lint.sh` if the repo has that gate.

## Local dev (tokens from project-context Tooling)
- Typecheck: none configured · Test: none configured
- Never run cloud deploys — those are manual ops actions outside agent scope.
