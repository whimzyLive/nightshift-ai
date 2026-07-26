---
id: payload-run-script-needs-top-level-await-not-fire-and-forget
agent: [web-engineer]
trigger: [payload run script exits 0 with zero effect, seed script silently produces nothing, IIFE not awaited]
rule: "`payload run <script>` (`await import(scriptPath)` then immediately `process.exit(0)`) only waits for a module's TOP-LEVEL `await` chain."
evidence: [NA-31]
uses: 0
status: active
---

## Why

Symptom: the script silently produces zero rows/updates and exits 0 with no error, no matter what
logging is added inside the unawaited function — none of that code ever gets a turn on the event
loop. Confirmed via a `process.exit` wrapper + stack trace pointing at the CLI's own `bin()`, not
anything in the script.
