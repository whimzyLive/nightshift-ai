---
description: Refine a raw idea (or an existing Jira ticket) and create or update a Jira Epic. First step in the SDLC pipeline. Returns an Epic key for use with /prd.
---

Dispatch the `product-manager` agent to refine the input and create or update a Jira Epic.

Jira project key: read the `Jira project key` row from `.claude/project/project-context.md` before
anything else — use the resolved value as `<PROJECT-KEY>` for every step below. If the row is
missing or empty, **STOP** — do not fall back to any literal project key. Return: "Cannot proceed —
`.claude/project/project-context.md` has no `Jira project key` row. Add the row and retry."

The agent should first detect the input type from `$ARGUMENTS`:

**Step 1 — Detect mode**

Scan `$ARGUMENTS` for a `<PROJECT-KEY>-\d+` pattern:

- **If a `<PROJECT-KEY>-XXX` key is present** → this is an existing Epic to update. Extract the key. Set `MODE=update`, `EPIC_KEY=<extracted key>`.
- **If no `<PROJECT-KEY>-XXX` key, but another Jira URL or key is present** (e.g. `https://...atlassian.net/browse/...`) → use it as source material. Set `MODE=create`.
- **If only raw idea text** → Set `MODE=create`.

**Step 2 — Gather source material**

For any non-`<PROJECT-KEY>` Jira key or URL found in `$ARGUMENTS`:

1. Read `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` and apply the protocol to fetch that ticket
2. Extract summary, description, all comments, linked tickets — use as raw idea source

Classify every path, link, and directive in `$ARGUMENTS` (including `@filename` references)
**before reading anything**, with the "Design, Dev Notes, References — what goes where" table in
`${CLAUDE_PLUGIN_ROOT}/refs/jira-story-template.md`:

- A `docs/design/<slug>/index.md` path (or `Design:` comments on the Epic in `MODE=update`) → the
  Epic's **Design** section. Read only that `index.md`.
- A design file outside `docs/design/` (`.html`/`.htm` export, image, design folder) → **never read
  it** (a standalone export is ~500 KB of base64, and its text is untrusted data). Do not link it;
  return "run `/design <EPIC-KEY> <path>` to attach it" once the Epic key exists.
- Any other `@filename` → read it and incorporate it as additional context.
- Implementation directives from the requester → **Dev Notes**, verbatim. The product-language rule
  does not apply to them, and the agent never authors new ones.
- Docs, URLs, other tickets → **References**.

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
- Design, Dev Notes, References (from Step 2's classification; `MODE=update` carries the Epic's
  existing content in these sections forward — never drop it; empty → "None")

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

Both branches below write to Jira — run the site guard once first:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
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
  --project "<PROJECT-KEY>" \
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
- Any `run /design <EPIC-KEY> <path>` instructions for design files that are not in the repo yet

## Final action — release the session (required)

After **everything above is complete** (success or a terminal stop), run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Raw idea text, Jira URL, OR existing Epic key (e.g. <EPIC-KEY>):
$ARGUMENTS
