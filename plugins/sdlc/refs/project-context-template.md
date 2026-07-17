# Project Context Template

This file is the canonical template for `.claude/project/project-context.md`.
`/init` Step 4b fills the token slots below with real values collected and
detected during setup. No placeholder tokens (`<...>`) may remain in the
generated file — every slot must be replaced with an actual value.

---

## Template

```markdown
# Project Context

| Token            | Value                |
| ---------------- | -------------------- |
| Project name     | <project name>       |
| Jira project key | <KEY>                |
| Jira site        | <site>               |
| Base branch      | <base branch>        |
| Package manager  | <pm>                 |
| Typecheck / Test | <typecheck> / <test> |

## Detected stack

| Signal           | Detected value       |
| ---------------- | -------------------- |
| Primary language | <DETECTED_LANG>      |
| Framework(s)     | <DETECTED_FRAMEWORK> |
| Package manager  | <DETECTED_PM>        |
| Test runner      | <DETECTED_TEST>      |

## Workspace → agent

| Path | Owner |
| ---- | ----- |

<one row per active agent: its owned path → the agent>

## Tooling

| Typecheck | `<typecheck cmd>` |
| Test | `<test cmd>` |

## Triage

| Token                                           | Value         |
| ----------------------------------------------- | ------------- |
| Lightweight threshold (story points, inclusive) | `<threshold>` |

## Code Review

| Token        | Value            |
| ------------ | ---------------- |
| Review agent | `<review-agent>` |
| Review mode  | `<review-mode>`  |
| Review gate  | `<review-gate>`  |
```

---

## Fill rules

- **Omit blank rows** — if the user left Typecheck or Test blank, omit those
  rows from `## Tooling` rather than writing an empty backtick pair.
- **Omit none-detected stack rows** — in `## Detected stack`, omit any row
  whose detected value is empty or `none`. Do not write `none` into the file.
- **Package manager appears twice** — once in the top table (user-confirmed
  choice) and once in `## Detected stack` (what was auto-detected). If the
  user changed the detected value, the top table reflects the confirmed choice;
  `## Detected stack` reflects what was auto-detected.
- **Workspace → agent rows** — write one row per active domain agent, mapping
  its confirmed owned path(s) to the agent name.
- **Code Review** — `<review-agent>` and `<review-mode>` come from the `/init`
  Step 3 _Review agent_ and _Review trigger_ pickers. Substitute the chosen values;
  when the values were not collected (e.g. the re-init merge path that skips Step 3),
  fall back to the picker defaults `Review agent = claude-inline` and
  `Review mode = on-update`. `claude-inline` is the default because it works on ANY
  repo with no external setup: the `/loop` runs `/code-review` in-session, so the
  review-fix cycle never silently no-ops on a repo that has not enabled GitHub Copilot
  code review. `github-copilot` is chosen only when the repo has Copilot code review
  enabled and prefers the bot to drive the loop. `claude-superpowers` is a second
  in-session option: the `/loop` runs the superpowers `requesting-code-review` skill
  (a focused reviewer subagent) instead of native `/code-review`, cutting per-review
  token cost while keeping the same review → fix → re-review cycle. `Review agent`
  accepts `claude-inline` / `github-copilot` / `claude-superpowers`; `Review mode`
  accepts `none` / `on-create` / `on-update`.
  > Note this `/init`-written default is distinct from the runtime FALLBACK: when
  > the `Review agent` token is **absent or unrecognised**, the loop falls back to
  > `github-copilot` (with a warning) for back-compatibility with older
  > project-context files. `/init` writes `claude-inline` **explicitly**, so new
  > repos get the in-session reviewer; pre-existing repos without the token keep
  > the historical Copilot behaviour.
- **Review gate** — OPTIONAL. A comma-separated subset of `spec,plan,impl` listing
  which phases trigger the configured review (e.g. `Review gate | spec, impl`). A
  phase not listed has its review skipped (effective review-mode `none` for that
  phase). **OMIT the row entirely when not gating** — an omitted/empty gate means
  all phases review, the default and back-compatible behaviour.
