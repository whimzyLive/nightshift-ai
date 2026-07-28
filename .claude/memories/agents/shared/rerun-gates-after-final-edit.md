---
id: rerun-gates-after-final-edit
agent: [ai-enablement-engineer, platform-engineer, web-engineer, mobile-engineer, database-administrator, sync-engineer, knowledge-engineer]
trigger: [about to report gate/test results, edited a file after running the gate, writing a memory or config file late in a dispatch]
rule: Re-run every gate AFTER your last edit and report what that run printed. A stale pass reported as fresh is worse than no claim — it suppresses the check the coordinator would otherwise run.
evidence: [NA-78]
uses: 0
status: active
---

## Why

On NA-78 a return reported `check-frontmatter.sh` → `OK`. The gate had been run before the
dispatch's memory file was written; that file's `rule:` field was 289 chars against a 200 cap, so
the branch was actually red on a required CI step while base was green. The claim was not invented —
it was true when made and stale by the time it was reported.

Memory and config files written late in a dispatch are the common trigger: the code work finishes,
gates get run, then a rule file or frontmatter is added as a final flourish and never re-checked.

Report the command and its actual output, not a recollection of an earlier run. If a gate was run
against a different tree state than the one you are handing over, it is not evidence.
