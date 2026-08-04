# Design note — why the orchestration playbooks run inline, not as subagents

**Never auto-loaded** — extracted from `refs/principal-engineer-playbook.md` and
`refs/qa-engineer-playbook.md` (NA-86 A10). Both playbooks already carry the operative guard this
note only explains: a **Step 0 "Nesting self-guard"** that checks whether the `Agent` tool is
available and STOPs/returns `blocked` if not. Removing this note changes no behaviour — the guard
itself lives at the point of use, not here.

## Why inline

Claude Code blocks subagent → subagent dispatch (nesting is one level deep, by design). The
Principal Engineer's entire job is to dispatch domain agents with the `Agent` tool; the QA
Engineer's entire job is to dispatch the `agent-skills:code-reviewer` subagent AND domain fix
agents. Both jobs need the `Agent` tool, which only works at the top level. If either playbook is
run as a dispatched subagent, it would be unable to dispatch anyone and would return `blocked`.

This is why `/impl` (and `/auto`'s implementation phase) execute the Principal Engineer playbook
**inline, in the top-level session**, and why that same top-level session continues running the QA
Engineer playbook inline once Step 6 hands off — never as a nested `principal-engineer` or
`qa-engineer` subagent dispatch.
