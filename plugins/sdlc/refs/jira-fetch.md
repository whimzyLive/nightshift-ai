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

**Step 1 — detect the populated field (check BOTH names; retry across index lag):**

JQL search reads Jira's Lucene **index**, which can **lag** a just-written field — and a cold-start
or transient `acli` failure can also look like an empty result. (This is the same indexing lag seen
elsewhere: a write returns `204` while a JQL read still shows the old state for a few seconds.) So a
single empty probe must **never** be trusted as `missing`: retry a few times with a short back-off,
and treat an `acli` **error** (non-zero exit) as *inconclusive*, not as `missing`.

```bash
FOUND_FIELD=""; LAST_ERR=0
for attempt in 1 2 3; do
  LAST_ERR=0
  for FIELD in "Story point estimate" "Story Points"; do
    out=$(acli jira workitem search --jql "key = <KEY> AND \"$FIELD\" is not EMPTY" --json 2>&1) || LAST_ERR=1
    printf '%s' "$out" | grep -qE '"key":[[:space:]]*"<KEY>"' && { FOUND_FIELD="$FIELD"; break; }
  done
  [ -n "$FOUND_FIELD" ] && break
  sleep 2   # no match yet — could be index lag or a transient error; back off and retry
done
```

Decide from the loop result — **only a clean, repeatable empty means `missing`**:

- `FOUND_FIELD` set → the field is populated → go to Step 2.
- `FOUND_FIELD` empty **and** `LAST_ERR=0` on the final attempt (a clean empty that persisted across
  all retries) → points are genuinely unset → `missing`.
- `FOUND_FIELD` empty **but** `LAST_ERR=1` persisted (every attempt errored — auth/DNS, or an
  ambiguous-field error) → **inconclusive: STOP and surface the error; do NOT report `missing`.** A
  transient/config error must never masquerade as "no points". A persistent *"field is ambiguous"*
  error means the instance has duplicate field names — for that one instance, disambiguate with the
  `cf[id]` form (the id from the project's field config) rather than the display name.

> The same JQL/index caveat applies to **any** by-name field read in this plugin (e.g. the
> `AI Workflow` mode probe). Before trusting an empty `… is not EMPTY` result as authoritative,
> apply this retry + error-aware discipline; a single empty probe is not proof the field is unset.

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

`acli` via Bash is the **only** Jira transport. Never call Atlassian MCP tools, and never reach for
direct HTTP to `api.atlassian.com` (or any other Jira REST endpoint) — not as a default, and **not as
a fallback**. Two independent reasons:

1. **Token cost** — an MCP call returns full JSON payloads into context (≈ 500–2000 tokens) vs `acli`'s
   ≈ 10–50 tokens.
2. **Reachability** — agent sandboxes routinely **network-block** `api.atlassian.com` while `acli`
   stays functional in the same sandbox. So MCP/HTTP is not just costlier, it is frequently the one
   path that does **not** work — falling back to it converts a working `acli` setup into a spurious
   "Jira unreachable" failure.

An `acli` failure is therefore a **STOP** (surface the error and let the operator fix `acli` access),
**never** a signal to switch to MCP or HTTP. Do not interpret "`acli` returned an error" or "the
network looks blocked" as permission to try another transport — there is exactly one transport.
