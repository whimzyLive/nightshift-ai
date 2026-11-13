---
description: Decompose a Jira Epic into user stories linked to the Epic. Run after the /prd and /design PRs are merged — both are optional; without a PRD the Epic description is the source.
---

Dispatch the `scrum-master` agent in **decompose mode**, with the output of
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/skills-for.sh scrum-master --mode decompose --print-prompt`, and the following input:

```
$ARGUMENTS
```

The scrum-master agent owns the full decompose workflow — Epic fetch, story mapping, decomposition, dependency ordering, and story creation. Do not repeat its instructions here. `/sdlc:design <EPIC> --plan` creates the Epic's `Design` story; the agent reuses it and links every UI screen story to it, so report its key with the rest. When that story is already Done, the screen stories name the final boards in their Design row and need no gate; when it is open, they are blocked by it until `/sdlc:design <EPIC> --final` has merged and a person closes it.

## Final action — release the session (required)

Once the scrum-master agent has returned and you have reported its result, run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.
