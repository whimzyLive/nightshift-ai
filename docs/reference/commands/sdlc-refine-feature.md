---
title: '/sdlc:refine-feature'
description: 'Refine a raw idea (or an existing Jira ticket) and create or update a Jira Epic. First step in the SDLC pipeline. Returns an Epic key for use with /prd.'
---

# /sdlc:refine-feature

Refine a raw idea (or an existing Jira ticket) and create or update a Jira Epic. First step in the SDLC pipeline. Returns an Epic key for use with /prd.

---

**Source:** `plugins/sdlc/commands/refine-feature.md`

Dispatch the `product-manager` agent to refine the input and create or update a Jira Epic.

The agent should first detect the input type from `$ARGUMENTS`:

**Step 1 — Detect mode**

Scan `$ARGUMENTS` for a `ET-\d+` pattern:

- **If an `ET-XXX` key is present** → this is an existing Epic to update. Extract the key. Set `MODE=update`, `EPIC_KEY=<extracted key>`.
- **If no `ET-XXX` key, but another Jira URL or key is present** (e.g. `https://...atlassian.net/browse/...`) → use it as source material. Set `MODE=create`.
- **If only raw idea text** → Set `MODE=create`.

**Step 2 — Gather source material**

For any non-ET Jira key or URL found in `$ARGUMENTS`:

1. Read `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` and apply the protocol to fetch that ticket
2. Extract summary, description, all comments, linked tickets — use as raw idea source

For any `@filename` references in `$ARGUMENTS`:

- Read those files and incorporate as additional context

For raw idea text — analyse: identify the user, the action, the outcome, what's ambiguous. Ask ONE clarifying question if critical info is missing; otherwise proceed.

**Step 3 — Synthesize**

Apply idea-refine thinking regardless of mode:

- Simplest version that delivers value
- Hidden assumptions
- Explicit non-goals

Apply product context: which roles are affected, is mobile/offline relevant.

Compose Epic description covering:

- Core idea (2–3 sentences)
- Target users (which product roles)
- Key value (what problem it solves)
- What it is NOT (scope boundaries)
- Open questions to resolve in PRD phase

**Step 4 — Create or Update**

⚠️ **ADF JSON required.** Read **`${CLAUDE_PLUGIN_ROOT}/refs/jira-adf.md`** before writing any description — it has the full node reference and a copy-paste Epic template. Save to a `.json` temp file (not `.txt` or `.md`).

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)   # session-scoped ./.tmp/<key>
epic_desc=$(mktemp "$dir/acli-desc-XXXXXX.json")
trap 'rm -f "$epic_desc"' EXIT
# Write ADF JSON from the Epic template in ${CLAUDE_PLUGIN_ROOT}/refs/jira-adf.md
cat > "$epic_desc" << 'EOF'
{ ... ADF JSON using Epic description template ... }
EOF
```

**If `MODE=update`:**

```bash
result=$(acli jira workitem edit \
  --key "$EPIC_KEY" \
  --summary "<concise concept title — max 8 words>" \
  --description-file "$epic_desc" \
  --yes \
  --json 2>&1)
echo "Updated Epic: $EPIC_KEY"
```

**If `MODE=create`:**

```bash
result=$(acli jira workitem create \
  --project ET \
  --type "Epic" \
  --summary "<concise concept title — max 8 words>" \
  --description-file "$epic_desc" \
  --json 2>&1)
epic_key=$(echo "$result" | jq -r '.key')
echo "Created Epic: $epic_key"
```

**Step 5 — Return**

Return:

- The Epic key (e.g. CER-100)
- Whether it was created or updated
- Any open questions still unresolved

## Final action — release the session (required)

After **everything above is complete** (success or a terminal stop), run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Raw idea text, Jira URL, OR existing Epic key (e.g. <EPIC-KEY>):
$ARGUMENTS
