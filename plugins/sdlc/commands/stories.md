---
description: Decompose a Jira Epic into user stories linked to the Epic. Run after the /prd and /design PRs are merged — both are optional; without a PRD the Epic description is the source.
---

Dispatch the `scrum-master` agent in **decompose mode**, with the output of
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/skills-for.sh scrum-master --mode decompose --print-prompt`, and the following input:

```
$ARGUMENTS
```

The scrum-master agent owns the full decompose workflow — Epic fetch, story mapping, decomposition, dependency ordering, and story creation. Do not repeat its instructions here. When the Epic has a component plan and its screens have no final boards yet, the agent also adds one `Design` story that blocks every UI screen story until `/sdlc:design <EPIC> --final` has merged; report its key with the rest.

## Final action — release the session (required)

Once the scrum-master agent has returned and you have reported its result, run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.
