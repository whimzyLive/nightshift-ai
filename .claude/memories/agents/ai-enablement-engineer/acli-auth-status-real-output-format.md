---
id: acli-auth-status-real-output-format
agent: [ai-enablement-engineer]
trigger: [parsing acli jira auth status output, mocking acli in a test, jira site guard script]
rule: When parsing or mocking `acli jira auth status`, use its real (1.3.22-stable) shape — "✓ Authenticated" then a "  Site: <site>" line — never an assumed/invented format.
evidence: [NA-77]
uses: 0
status: active
---

## Why

Nothing under `plugins/sdlc/` documents `acli jira auth status`'s actual stdout shape — every
existing guard (`commands/init.md`, `skills/acli/SKILL.md`) only checks the exit code, never parses
the body. Running the real installed binary (`acli jira auth status`) shows:

```
✓ Authenticated
  Site: <site>
  Email: <email>
  Authentication Type: oauth
```

A script or mock that guesses at this (e.g. a "Profile:"/"Active site:" shape) will silently fail
against the real CLI. Confirm against the installed binary before writing a parser or a test mock.
