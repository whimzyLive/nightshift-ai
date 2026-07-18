---
name: gh-cli
description: Use gh (GitHub CLI) for all GitHub operations — creating PRs, checking status, commenting, and capturing URLs. Prefer gh over GitHub MCP tools to minimize token usage.
---

# gh-cli — GitHub CLI

Use `gh` for all GitHub operations. Never use GitHub MCP tools when gh can do the same job.

## Why gh over MCP

MCP tool calls return full JSON payloads into context. gh runs in Bash, outputs only what you request, and exits. Token cost per operation: gh ≈ 10–50 tokens vs MCP ≈ 500–2000 tokens.

## Authentication

gh reads credentials from `~/.config/gh/`. Assume it is authenticated. If a command returns an auth error, stop and tell the user to run `gh auth login`.

## Full PR creation workflow

Always follow this order — never skip steps:

```bash
# 1. Push branch to remote
git push -u origin "$(git branch --show-current)"

# 2. Check for existing PR — never create duplicates
existing=$(gh pr list --head "$(git branch --show-current)" --json url --jq '.[0].url // empty' 2>&1)
if [ -n "$existing" ]; then
  echo "PR already exists: $existing"
  exit 0
fi

# 3. Create PR — always use heredoc for body to avoid shell escaping issues
pr_url=$(gh pr create \
  --title "feat(scope): description" \
  --base develop \
  --body "$(cat <<'EOF'
## Summary
- What this PR does (bullet points)

## Test plan
- [ ] Verification step
EOF
)" 2>&1)

echo "Created PR: $pr_url"
```

## Create a PR (minimal form)

```bash
gh pr create \
  --title "feat(scope): description" \
  --base develop \
  --body "$(cat <<'EOF'
## Summary
- <what changed and why>

## Test plan
- [ ] <how to verify>
EOF
)"
```

## Shell escaping rule

**Always use single-quoted `<<'EOF'`** for PR bodies — prevents variable expansion inside the body:

```bash
# CORRECT — $ENTITY is treated as literal text
--body "$(cat <<'EOF'
## Summary
- Added $ENTITY support
EOF
)"

# WRONG — shell expands $ENTITY, breaks the body
--body "$(cat <<EOF
## Summary
- Added $ENTITY support
EOF
)"
```

## Core commands

### View PR (minimal output — never dump full view)

```bash
# State + title + URL
gh pr view --json url,state,title --jq '"\(.state) — \(.title) — \(.url)"'

# Review status
gh pr view --json reviewDecision,mergeable --jq '"\(.reviewDecision) / \(.mergeable)"'
```

### List PRs for current branch

```bash
gh pr list \
  --head "$(git branch --show-current)" \
  --json number,title,url,state \
  --jq '.[] | "\(.number) [\(.state)] \(.title) — \(.url)"'
```

### Add comment to PR or issue

```bash
gh pr comment <number-or-url> --body "Spec ready: docs/superpowers/specs/CER-123-design.md"
gh issue comment <number> --body "Comment text"
```

### Check CI status

```bash
gh pr checks --json name,state,conclusion \
  --jq '.[] | "\(.name): \(.conclusion // .state)"'
```

### Merge a PR (when authorized)

```bash
gh pr merge <number-or-url> --squash --delete-branch
```

## Branch conventions

| Artifact   | Branch pattern           |
| ---------- | ------------------------ |
| Idea doc   | `ideas/<slug>`           |
| PRD        | `feature/prd-<slug>`     |
| Spec       | `spec/<JIRA-KEY>`        |
| Plan       | `plan/<slug>`            |
| DB changes | `feat/db/<feature>`      |
| Backend    | `feat/backend/<feature>` |
| Sync       | `feat/sync/<feature>`    |
| Web        | `feat/web/<feature>`     |
| Mobile     | `feat/mobile/<feature>`  |

## PR title conventions

| Phase    | Title format                             |
| -------- | ---------------------------------------- |
| Idea doc | `docs(idea): <concept title>`            |
| PRD      | `docs(prd): <feature title>`             |
| Spec     | `docs(spec): <JIRA-KEY> <story summary>` |
| Plan     | `docs(plan): <JIRA-KEY> <feature title>` |
| DB       | `feat(db): <description>`                |
| Backend  | `feat(backend): <description>`           |
| Sync     | `feat(sync): <description>`              |
| Web      | `feat(web): <description>`               |
| Mobile   | `feat(mobile): <description>`            |

## PR body template per phase

### Doc artifact PR (idea / PRD / spec / plan)

```
## Summary
- Adds <artifact type> for <feature/story name>
- Covers: <key decisions made>

## Review checklist
- [ ] Acceptance criteria are binary (done/not done)
- [ ] No open TBDs without a suggested default
- [ ] Scope boundaries are explicit
```

### Implementation PR (DB / backend / sync / web / mobile)

```
## Summary
- Implements <story key>: <story summary>
- Changes: <list of key changes>

## Test plan
- [ ] Project typecheck passes (command from project-context)
- [ ] Project lint passes (command from project-context)
- [ ] <manual verification step>

## Jira
<JIRA-KEY>
```

## Capturing PR URL

```bash
pr_url=$(gh pr create --title "..." --base develop --body "..." 2>&1)
echo "PR: $pr_url"
# Use $pr_url in follow-up acli comments or return value
```

## Error handling

| Error                     | Fix                                                     |
| ------------------------- | ------------------------------------------------------- | ------------- |
| Auth error                | Tell user: `gh auth login`                              |
| Branch not pushed         | `git push -u origin $(git branch --show-current)` first |
| PR already exists         | Report existing URL, do NOT create duplicate            |
| No commits ahead of base  | Nothing to PR — stop and report                         |
| `--base` branch not found | Confirm base branch: `git branch -r                     | grep develop` |
