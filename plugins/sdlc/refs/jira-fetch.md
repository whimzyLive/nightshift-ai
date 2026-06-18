# Jira fetch protocol

Standard "fetch everything we know about a Jira issue" block. Reference this from any command or agent that needs to read an issue's full context. Replaces the four-call block previously inlined across `/refine-feature`, `/prd`, `/stories`, `/spec`, `/plan`, `/impl`, `/refine-issue`, `scrum-master`, and `solutions-architect`.

## Inputs

- `<KEY>` — a Jira issue key (Epic or Story), e.g. `ED-100`, `ED-456`. Project key is in `.claude/project/project-context.md` — never fetch it via acli.

## Calls (always parallel)

Run all four in parallel — they are independent:

```bash
acli jira workitem view <KEY> --json                                # summary + description + status + parent + fields
acli jira workitem comment list --key <KEY> --json --paginate       # all comments, newest first
acli jira workitem link list --key <KEY> --json                     # linked Jira tickets (blocks, is blocked by, child of, etc.)
acli jira workitem attachment list --key <KEY> --json               # attachment filenames + URLs
```

## What to extract

From the JSON output collectively:

- Summary, description, status, parent key (Epic for a Story).
- All comment bodies — agents often leave breadcrumbs here (`PRD: docs/features/...`, `Spec: docs/superpowers/specs/...`, `Plan: docs/superpowers/plans/...`).
- Linked tickets — to walk Epic ↔ Story relationships.
- Attachment filenames — for product-decision context.

## What is NOT available

- **External URLs** in description or comments (Figma, Confluence, Slack threads) cannot be opened via `acli` — surface them as references but do not try to fetch.
- **Custom fields** beyond what `--json` returns — request them explicitly with `--fields` if needed.

## Reading story points

`acli view`/`search --json` does **not** reliably render the story-points custom field, and the field **name differs by project type**:

- **Scrum / sprint-based** projects → `Story Points`
- **Team-managed / Kanban** projects → `Story point estimate`

Both fields can exist in the same Jira instance, but each project populates only one. Read by **JQL probe on the field NAME** — never by a hard-coded `customfield_*` id (ids vary by instance) and never by trusting `fields.*` in the view JSON.

**Step 1 — detect the populated field (check BOTH names):**

```bash
for FIELD in "Story point estimate" "Story Points"; do
  n=$(acli jira workitem search --jql "key = <KEY> AND \"$FIELD\" is not EMPTY" --json 2>/dev/null | grep -c '"key": "<KEY>"')
  [ "$n" != "0" ] && echo "POPULATED: $FIELD"
done
```

If **neither** name returns a match → points are genuinely unset (`missing`). Only report `missing` when BOTH return nothing.

**Step 2 — read the value via candidate probe on the populated field:**

```bash
for V in 1 2 3 5 8 13 20 21 40; do
  acli jira workitem search --jql "key = <KEY> AND \"<FIELD>\" = $V" --json 2>/dev/null | grep -q '"key": "<KEY>"' && { echo "POINTS=$V"; break; }
done
```

If the field is non-empty (Step 1 matched) but no candidate matches, the value is non-standard — **widen the candidate set; do NOT report `missing`** (the field IS set).

## Walking Epic ↔ Story

For a Story, the Epic key is in the `parent` field of the view JSON.

**Guard before fetching Epic:** Check the `parent` field in the story view JSON response first. If `parent` is `null`, absent, or an empty object — stop. Do NOT fire the four calls. Only re-run the four calls with the Epic key when `parent` is non-null and contains a valid issue key.

## Fetching sub-tasks

The story `view --json` response does **not** include a story's child sub-tasks. Enumerate them with a dedicated JQL probe on the parent key — this is the source of truth for sub-tasks:

```bash
acli jira workitem search --jql "parent = <KEY> AND issuetype in subTaskIssueTypes() ORDER BY created ASC" --fields "key,summary" --json
```

- Use the `subTaskIssueTypes()` JQL function rather than a hard-coded `issuetype = Sub-task`. Sub-task issue types can be **renamed or differ per instance** (e.g. "Subtask", "Sub-task", localized names); `issuetype = Sub-task` would either miss them or raise a JQL error ("The value 'Sub-task' does not exist for the field 'issuetype'") on an instance without a type by that exact name. `subTaskIssueTypes()` resolves to whatever sub-task types the instance actually has.
- The result is an ordered list of `{ key, summary }`. Ordering is **explicit via `ORDER BY created ASC`** (creation order) — JQL does not guarantee any order without it. Do not re-sort by key or summary.
- When the story has no sub-tasks — or the instance has **no sub-task issue types at all** (`subTaskIssueTypes()` resolves to an empty set) — the probe returns an **empty result array, not an error**. Treat an empty array as "no sub-tasks" and take the no-op path.
- Only treat a **non-empty error** (auth/DNS/malformed JQL) as a failure → STOP, consistent with the `acli`-failure rule above.

## Tooling rule

Always use `acli` via Bash. Never call Atlassian MCP tools — token cost is significantly higher.
