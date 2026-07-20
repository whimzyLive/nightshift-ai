---
title: '/sdlc:stories'
description: 'Decompose a Jira Epic into user stories linked to the Epic. Run after /prd PR is reviewed and merged.'
related-adrs: []
---

# /sdlc:stories

Decompose a Jira Epic into user stories linked to the Epic. Run after /prd PR is reviewed and merged.

---

**Source:** `plugins/sdlc/commands/stories.md`

Dispatch the `scrum-master` agent in **decompose mode** with the following input:

```
$ARGUMENTS
```

The scrum-master agent owns the full decompose workflow — Epic fetch, story mapping, decomposition, dependency ordering, and story creation. Do not repeat its instructions here.

## Final action — release the session (required)

Once the scrum-master agent has returned and you have reported its result, run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.
