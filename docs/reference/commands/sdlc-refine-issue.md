---
title: '/sdlc:refine-issue'
description: 'Triage an unpolished Jira story or a raw text/idea blob into a well-formed story. Refines existing tickets in-place or creates new ones. Use when a story is incomplete, when you receive a rough ticket from a stakeholder, or when raw input needs to be formalised into Jira before it enters the /spec pipeline.'
---

# /sdlc:refine-issue

Triage an unpolished Jira story or a raw text/idea blob into a well-formed story. Refines existing tickets in-place or creates new ones. Use when a story is incomplete, when you receive a rough ticket from a stakeholder, or when raw input needs to be formalised into Jira before it enters the /spec pipeline.

---

**Source:** `plugins/sdlc/commands/refine-issue.md`

Dispatch the `scrum-master` agent in **triage mode** with the following input:

```
$ARGUMENTS
```

The scrum-master agent owns the full triage workflow — story fetch, gap assessment, ADF rewrite, Jira update, and comment. Do not repeat its instructions here.

## Final action — release the session (required)

Once the scrum-master agent has returned and you have reported its result, run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.
