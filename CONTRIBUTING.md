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
stack names, or hardcoded paths. Project specifics belong in the *consuming* repo's
`.claude/project/` (project-context + agent overrides), never in the plugin.

A lint enforces this. **Run it before every PR:**

```bash
bash tools/portability-lint.sh
# expect: "portability-lint: clean (0 project tokens)"
```

If it flags a line, replace the literal with a token/pointer to `project-context.md`, or move the
specifics into a per-repo override. (See the README's "Extend the agents to your stack" section.)

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

## Pull request checklist

- [ ] `bash tools/portability-lint.sh` is clean.
- [ ] No project-specific tokens added to `plugins/sdlc/**`.
- [ ] JSON manifests validate.
- [ ] If you added an agent/command, you tested it installed against a real repo.
- [ ] Commit messages are conventional (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).
- [ ] README/docs updated if behavior or install steps changed.

## Reporting bugs & ideas

Open an [issue](https://github.com/whimzyLive/nightshift-ai/issues). For bugs, include your Claude
Code version, the agent/command involved, and the relevant slice of your `project-context.md`
(redact secrets). For features, describe the workflow you want — roles, adapters, or stacks.

## License

By contributing, you agree your contributions are licensed under the [MIT License](LICENSE).
