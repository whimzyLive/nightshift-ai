---
name: acli
description: Use acli (Atlassian CLI) to interact with Jira Cloud — create, search, view, link, and edit work items via shell commands instead of MCP tools. Prefer acli over Atlassian MCP to minimize token usage.
---

# acli — Atlassian CLI for Jira

`acli` via Bash is the only Jira transport. Never use Atlassian MCP tools or direct HTTP to `api.atlassian.com` — not even as a fallback. An `acli` failure is a STOP (surface it), not a signal to switch transports.

## ⚠️ Description formatting — ADF JSON required

**Before writing any description or comment to Jira, read `.claude/refs/jira-adf.md`.**

`acli --description-file` passes the file contents directly to the Jira API. Plain markdown renders as raw symbols (e.g. `**bold**` appears literally). All descriptions must be Atlassian Document Format (ADF) JSON, saved to a `.json` temp file. The ref contains the full node reference, mark types, and ready-to-use Epic and Story templates.

## Why acli over MCP

MCP tool calls return full JSON payloads into context. acli runs in Bash, outputs only what you request, and exits. Token cost per operation: acli ≈ 10–50 tokens vs MCP ≈ 500–2000 tokens.

## Authentication

acli reads credentials from `~/.config/acli/`. Before any acli command, run this auth guard:

```bash
# 1. DNS reachability check — fail fast if Atlassian is blocked
if ! getent hosts "$ATLASSIAN_SITE" >/dev/null 2>&1; then
  echo "ERROR: $ATLASSIAN_SITE is DNS-blocked in this environment." >&2
  echo "Fix: allowlist $ATLASSIAN_SITE and api.atlassian.com in GitHub → Settings → Copilot → Policies." >&2
  exit 1
fi

# 2. Re-authenticate if no valid profile (Copilot agent sessions don't share ~/.config/acli from setup steps)
acli jira auth status 2>/dev/null || \
  echo "$ATLASSIAN_API_TOKEN" | acli jira auth login \
    --site "$ATLASSIAN_SITE" \
    --email "$ATLASSIAN_EMAIL" \
    --token
```

`ATLASSIAN_API_TOKEN` and `ATLASSIAN_EMAIL` are injected as environment variables by the Copilot agent runtime from repository Copilot secrets. If both are empty and auth fails, abort: "ATLASSIAN_API_TOKEN/ATLASSIAN_EMAIL not set — configure in GitHub → Settings → Secrets → Copilot."

`ATLASSIAN_SITE` must be set alongside `ATLASSIAN_EMAIL` / `ATLASSIAN_API_TOKEN`. Its value is the Jira site hostname from the consumer's project-context (e.g. `your-org.atlassian.net`).

## Core commands for story/workitem management

### Check available projects

```bash
acli jira project list --json 2>&1 | jq '.[].key'
```

### Search for existing epics

```bash
acli jira workitem search \
  --jql "project = CER AND issuetype = Epic AND summary ~ \"feature keyword\"" \
  --fields "key,summary" --json 2>&1
```

### Create a single work item

```bash
acli jira workitem create \
  --project "CER" \
  --type "Story" \
  --summary "Short action-oriented title" \
  --description "As a fire safety engineer\nI want to...\nSo that..." \
  --label "feature-slug" \
  --parent "CER-123" \
  --json 2>&1
```

Flags reference:
| Flag | Purpose |
|---|---|
| `-p, --project` | Jira project key (e.g. `CER`) |
| `-t, --type` | Work item type: `Story`, `Task`, `Bug`, `Epic`, `Sub-task` |
| `-s, --summary` | Title (max 255 chars) |
| `-d, --description` | Body text — use `\n` for newlines |
| `--description-file` | Read description from a file (prefer for long ACs) |
| `--parent` | Parent issue key — use for Epic linkage |
| `-l, --label` | Comma-separated labels |
| `-a, --assignee` | Email or `@me` |
| `--json` | Output created issue as JSON (captures the new issue key) |

### Bulk create from JSON (preferred for multiple stories)

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)   # session-scoped ./.tmp/<key>
bulk_file=$(mktemp "$dir/acli-bulk.XXXXXX")
trap 'rm -f "$bulk_file"' EXIT

# ... write JSON to $bulk_file, then:
acli jira workitem create-bulk --from-json "$bulk_file" 2>&1
```

JSON format for the bulk file:

```json
[
  {
    "summary": "Story title",
    "projectKey": "CER",
    "issueType": "Story",
    "description": "As a...\nI want to...\nSo that...",
    "labels": ["feature-slug"],
    "parentKey": "CER-123"
  }
]
```

Generate a template:

```bash
acli jira workitem create --generate-json
```

### View a work item (full context)

Always extract all available context when using a ticket as a source. Use dedicated subcommands — not all data is embedded in the `view` response:

```bash
KEY="CER-456"

# Core fields (summary + description embedded in view)
issue=$(acli jira workitem view "$KEY" --json 2>&1)
summary=$(echo "$issue" | jq -r '.fields.summary')
description=$(echo "$issue" | jq -r '.fields.description // ""')

# All comments — use dedicated subcommand
comments=$(acli jira workitem comment list --key "$KEY" --json --paginate 2>&1 | \
  jq -r '[.[].body] | join("\n---\n")' 2>/dev/null || echo "")

# Jira-to-Jira linked tickets only. NOTE: acli only exposes outwardIssueKey (= issue this one
# BLOCKS). "is blocked by" links show outwardIssueKey=null and the blocker key is NOT returned.
jira_links=$(acli jira workitem link list --key "$KEY" --json 2>&1 | \
  jq -r '.issueLinks[]? | "\(.typeName): blocks \(.outwardIssueKey // "(blocked-by upstream — key not exposed)")"' 2>/dev/null || echo "")

# Attachments — list only (filename + MIME type + URL), no download via acli
attachments=$(acli jira workitem attachment list --key "$KEY" --json 2>&1 | \
  jq -r '[.[] | "\(.filename) [\(.mimeType)]: \(.content)"] | join("\n")' 2>/dev/null || echo "")

echo "=== SUMMARY ===" && echo "$summary"
echo "=== DESCRIPTION ===" && echo "$description"
echo "=== COMMENTS ===" && echo "$comments"
echo "=== LINKED JIRA TICKETS ===" && echo "$jira_links"
echo "=== ATTACHMENTS ===" && echo "$attachments"
```

**Known limitations:**

- `acli jira workitem remote-links` does **not** exist — external/remote links (Confluence, Figma, Slack URLs) are NOT accessible via acli. Use the Jira REST API if you need them.
- Attachment download is not supported by acli. The `content` URL in the attachment list requires Jira auth headers that acli does not expose.
- `acli auth token` does **not** exist.

Raw JSON (when you need to parse specific fields):

```bash
acli jira workitem view CER-456 --json 2>&1
```

### Edit a work item

```bash
acli jira workitem edit CER-456 \
  --summary "Updated title" \
  --description "Updated description" 2>&1
```

### Link work items (dependencies)

```bash
acli jira workitem link type 2>&1   # available link type names (e.g. Blocks, Relates, Cloners)
```

Use the `link create` form with `--out`/`--in` — NOT the positional `link A B` form (unreliable).

**⚠️ acli direction is counter-intuitive (verified against the Jira UI): `--in` is the BLOCKER, `--out` is the BLOCKED issue.** To express "**A blocks B**" (A is the prerequisite that B depends on):

```bash
# A blocks B   →   --out <B, blocked/downstream>   --in <A, blocker/prerequisite>
acli jira workitem link create --out CER-102 --in CER-101 --type Blocks --yes 2>&1
```

**Reading links back** — `acli jira workitem link list --key <KEY> --json` returns
`{ "issueLinks": [ { "id", "typeName", "outwardIssueKey" } ] }`:

- `outwardIssueKey` (non-null) = an issue this story **blocks** (downstream).
- A null `outwardIssueKey` = an "**is blocked by**" (upstream) link — acli does **NOT** expose the blocker's key.
- To find what blocks `<KEY>`, invert: a sibling `S` blocks `<KEY>` iff `S`'s link list has `outwardIssueKey == <KEY>`. Or read the Jira UI's "is blocked by" section.

```bash
# Delete a link by its id (from link list)
acli jira workitem link delete --id <LINK-ID> --yes 2>&1
```

### Search with JQL

```bash
# Stories in a project
acli jira workitem search \
  --jql "project = CER AND issuetype = Story AND labels = \"feature-slug\"" \
  --fields "key,summary,status" \
  --json 2>&1

# Count only
acli jira workitem search \
  --jql "project = CER AND issuetype = Story" \
  --count 2>&1
```

### Add comment

```bash
acli jira workitem comment add CER-456 --body "Spec ready: docs/superpowers/specs/..." 2>&1
```

## Workflow pattern for story creation

Always follow this order to avoid creating orphaned stories:

```
1. Search for existing Epic matching feature area
2. Write all story descriptions to mktemp files (avoids shell escaping issues AND collisions)
3. Use create-bulk with --from-json for efficiency
4. Capture returned issue keys
5. Link blocking dependencies between stories
6. Comment on each story with the feature doc path
7. Temp files are auto-cleaned by the EXIT trap
```

## Shell escaping rules

Description text often contains special characters. Use files instead of inline strings.

Always use `mktemp` for temp files — write them under the session-scoped temp dir from
`scripts/tmp-dir.sh` (worker → `./.tmp/<SDLC_SESSION_KEY>`, interactive → `./.tmp/<CLAUDE_CODE_SESSION_ID>`;
inside the permission scope, gitignored), never `/tmp` (prompts on every access). The dir is
unique per session in BOTH modes, so the `SessionEnd` hook (`cleanup-tmp.sh`) and
`session-complete.sh` reliably remove it at teardown. This guarantees a unique path, keeps each
session's temp files isolated, and pairs with a `trap` for per-file cleanup:

```bash
# Create a unique temp file in the session temp dir; clean it up automatically on exit
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)   # session-scoped ./.tmp/<key>
desc_file=$(mktemp "$dir/acli-desc.XXXXXX")   # X's at end (macOS), no .txt suffix
trap 'rm -f "$desc_file"' EXIT

cat > "$desc_file" << 'EOF'
As a fire safety engineer
I want to view a list of penetrations by room
So that I can track certification status without opening each record

**Acceptance Criteria**
- [ ] List shows penetration ID, type, status, and last inspection date
- [ ] List filters by status (certified / pending / failed)
- [ ] Empty state shown when no penetrations exist

**Out of Scope**
- Editing penetrations from this view
EOF

acli jira workitem create \
  --project "CER" \
  --type "Story" \
  --summary "View penetrations list by room" \
  --description-file "$desc_file" \
  --parent "CER-123" \
  --json 2>&1
```

> `mktemp` returns a path like `./.tmp/<session>/acli-desc.A3f9kB` — unique per invocation, never collides with parallel runs. `trap ... EXIT` fires on normal exit, errors, and interrupts.

## Capturing created issue keys

```bash
result=$(acli jira workitem create --project CER --type Story --summary "Title" --json 2>&1)
key=$(echo "$result" | jq -r '.key')
echo "Created: $key"
```

## Error handling

- DNS block (`getent hosts "$ATLASSIAN_SITE"` fails) → abort immediately with the DNS-block error message above; do NOT attempt auth or any other acli command
- Auth error (DNS resolves but acli returns auth failure) → run the auth guard block above; if env vars empty, abort with "ATLASSIAN_API_TOKEN/ATLASSIAN_EMAIL not set"
- Project not found → run `acli jira project list` to confirm key
- Parent not found → verify epic key exists with `acli jira workitem view <key>`
- Rate limit → add `sleep 1` between bulk operations
