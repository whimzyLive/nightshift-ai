# Contributing to nightshift

Thanks for helping make nightshift better. Contributions of all sizes are welcome — new agents,
commands, skills, stack starter-configs, issue-tracker adapters, and docs.

## Repository layout

```
nightshift/
├── .claude-plugin/
│   └── marketplace.json        # the "nightshift" marketplace manifest
├── plugins/
│   └── sdlc/                   # the sdlc plugin (the thing people install)
│       ├── .claude-plugin/plugin.json
│       ├── agents/             # 11 generic role agents (zero project specifics)
│       ├── commands/           # 10 slash commands
│       ├── refs/               # shared playbooks/templates the agents read
│       ├── skills/             # generic skills bundled with the plugin
│       ├── scripts/            # workflow scripts (run from command/hook context)
│       └── hooks/              # SessionStart hook (project-context + plugin-root marker)
├── tools/
│   └── portability-lint.sh     # CI guard: keeps the generic tier project-agnostic
├── README.md
└── LAUNCH.md
```

## The one rule: keep the generic tier generic

nightshift's whole value is that the plugin works in **any** repo. So the shipped plugin
(`plugins/sdlc/**`) must contain **zero project-specific tokens** — no company names, Jira keys,
stack names, or hardcoded paths. Project specifics belong in the _consuming_ repo's
`.claude/project/` (project-context + agent overrides), never in the plugin.

A lint enforces this. **Run it before every PR:**

```bash
bash tools/portability-lint.sh
# expect: "portability-lint: clean"
```

It runs several checks: no machine-absolute paths, no `./${CLAUDE_PLUGIN_ROOT}` regressions, no
author emails/PII, no forbidden agent frontmatter (`hooks`/`mcpServers`/`permissionMode`), every
skill has a `SKILL.md`, agents/commands have the right frontmatter, and manifests are valid JSON.

If it flags a line, replace the literal with a token/pointer to `project-context.md`, or move the
specifics into a per-repo override. (See [EXTENDING.md](EXTENDING.md).)

**Forks that dogfood the plugin in their own org** can add a `tools/portability-denylist.txt`
(one regex per line) listing their company/Jira/stack tokens — the lint will then also fail if any
of those leak into the plugin. The file is gitignored-by-convention and absent by default, so the
public plugin stays org-neutral.

## Local development

The installed plugin can point straight at your working copy, so edits show up without reinstalling:

```text
/plugin marketplace add /absolute/path/to/your/clone/nightshift
/plugin install sdlc@nightshift
```

Then iterate in a test repo that has a `.claude/project/project-context.md`. After changing the
SessionStart hook or manifests, start a **fresh** Claude Code session (hooks fire at session start).

### Gotchas worth knowing

- **`${CLAUDE_PLUGIN_ROOT}` is only available to hooks and slash commands — not subagents.** Agents
  resolve plugin-bundled files via the `.claude/.sdlc-plugin-root` marker the SessionStart hook
  writes. If you add an agent that must read a bundled ref/script, follow the existing
  "Resolving plugin paths" pattern in the agent headers.
- **Skills are invoked by name**, across any installed plugin — prefer a skill over hardcoding a path.
- **Manifests are JSON** — validate after editing (`python3 -c 'import json;json.load(open("path"))'`).

## How to contribute, by type

- **A new skill** → `plugins/sdlc/skills/<name>/SKILL.md`. Keep it generic; reference `project-context`
  tokens instead of literals.
- **A new command** → `plugins/sdlc/commands/<name>.md`. Scripts it runs go in `scripts/` and are
  invoked as `${CLAUDE_PLUGIN_ROOT}/scripts/...` (command context expands the variable).
- **A new agent / role** → `plugins/sdlc/agents/<name>.md`. Mirror an existing agent's structure
  (first-steps that read project-context + the override, ownership from the workspace→agent table,
  generic `skills:` preload only). No project tech in the body.
- **A stack starter-config** → docs/example `project-context.md` + override files for a common stack.
- **An adapter** (GitLab/Linear/etc.) → discuss in an issue first; these touch refs + commands broadly.

## Releasing

Plugin versions (`plugins/sdlc/.claude-plugin/plugin.json`, `plugins/gtm/.claude-plugin/plugin.json`)
are bumped, tagged, and changelogged automatically by **`nx release`**, driven by your commits — you
never hand-edit a plugin's `version` field. Each plugin is versioned **independently**; root
`package.json` (`@nightshift-ai/source`, `0.0.0`, `private: true`) is never released and stays `0.0.0`.

### Commit contract

Scope your commit to the plugin name (`sdlc` or `gtm`) — that scope is what routes the commit to a
project and drives its bump. The commit **type** sets the bump magnitude (Nx's default conventional-commits
mapping — no custom `types` override needed):

| Commit type / marker                                                | Bump  |
| ------------------------------------------------------------------- | ----- |
| `feat`                                                              | minor |
| `fix`                                                               | patch |
| `!` suffix or a `BREAKING CHANGE:` footer (any type)                | major |
| `chore`, `docs`, `refactor`, `perf`, `build`, `test`, `ci`, `style` | none  |

**One plugin per commit.** With `useCommitScope: true`, a commit that touches a project's files but
carries a _different_ scope is still treated as a `patch` for that project — so a commit mixing
`sdlc` and `gtm` changes under one `(gtm)` scope would silently patch-bump `sdlc` too. Keep every
commit scoped to exactly the one plugin it changes.

### Running a release

```bash
# Dry run first — always. Prints the computed bump, the sdlc@X.Y.Z / gtm@X.Y.Z tag, and the
# CHANGELOG.md diff for each plugin. Writes, tags, and commits NOTHING.
pnpm nx release --dry-run

# Release both plugins:
pnpm nx release

# Release a single plugin:
pnpm nx release --projects=sdlc
pnpm nx release --projects=gtm
```

A real run updates the plugin's `plugin.json` `version`, writes/updates its `CHANGELOG.md`, commits,
and creates the `sdlc@X.Y.Z` / `gtm@X.Y.Z` git tag. It does not publish anywhere or open a GitHub
Release — releases are maintainer-invoked, not run in CI.

### One-time baseline-tag backfill

`nx release` resolves each project's current version from its latest matching git tag
(`{projectName}@{version}`), falling back to reading `plugin.json` from disk when no tag exists yet.
Until the first baseline tags exist, every dry/real run recomputes the bump from the plugin's entire
commit history instead of "since the last release." A maintainer backfills this **once**, cut from
the tip of `main` (the published branch — not `develop`, which can be ahead of what's shipped):

```bash
git checkout main && git pull
git tag -a sdlc@0.42.0 -m "sdlc 0.42.0 (baseline)"
git tag -a gtm@0.5.0   -m "gtm 0.5.0 (baseline)"
git push origin sdlc@0.42.0 gtm@0.5.0
```

These tag names use the exact `releaseTag.pattern` nx.json is configured with, so `nx release`
matches them going forward. After backfill, the first real `feat`/`fix` release bumps from
`0.42.0` / `0.5.0` and computes its changelog only from commits after these tags.

## Pull request checklist

- [ ] `bash tools/portability-lint.sh` is clean.
- [ ] No project-specific tokens added to `plugins/sdlc/**`.
- [ ] JSON manifests validate.
- [ ] If you added an agent/command, you tested it installed against a real repo.
- [ ] Commit messages are conventional (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`) and scoped to
      the plugin you changed (`sdlc`/`gtm`) — the scope and type now drive that plugin's `nx release`
      version bump (see "Releasing" above).
- [ ] README/docs updated if behavior or install steps changed.

## Reporting bugs & ideas

Open an [issue](https://github.com/whimzyLive/nightshift-ai/issues). For bugs, include your Claude
Code version, the agent/command involved, and the relevant slice of your `project-context.md`
(redact secrets). For features, describe the workflow you want — roles, adapters, or stacks.

## License

By contributing, you agree your contributions are licensed under the [MIT License](LICENSE).
