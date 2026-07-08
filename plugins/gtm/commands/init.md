---
description: Bootstrap the gtm marketing foundation for this repo — installs the Postiz and marketing-skills dependencies, gates on Postiz reachability, detects product info, invokes the marketingskills product-marketing skill, configures per-channel Postiz ownership/voice/cadence/content-types, and atomically writes marketing-context.md plus the docs/gtm/ scaffold. Safe to re-run (keep/merge/rerun, never silently overwrites).
---

Bootstrap **this repository's** GTM marketing foundation — the marketing counterpart to sdlc's
`/init`. `$ARGUMENTS` is ignored — `/gtm:init` is always interactive.

This command performs **all its own setup work in-command** — dependency install, detection, the
product-marketing interview (via a skill invocation), and every config write happen here; there is
**no agent dispatch**. Run the steps below **in strict order, top to bottom**, and **STOP** at the
first failure with an actionable message — a failed prerequisite must never leave half-written
config.

## Step 0 — Re-init guard

Before doing anything else, check whether `.claude/project/marketing-context.md` already exists:

```bash
[ -f ".claude/project/marketing-context.md" ] && echo "EXISTING=yes" || echo "EXISTING=no"
```

**If `EXISTING=no`** — proceed to Step 1 normally (fresh init).

**If `EXISTING=yes`** — do not overwrite (AC-4). Read the existing file to capture its current
values, then ask:

```
AskUserQuestion(
  header: "Existing config",
  question: "This repo already has a gtm marketing foundation. How would you like to proceed?",
  multiSelect: false,
  options: [
    { label: "Keep existing",        description: "Stop now — no files will be changed." },
    { label: "Merge new findings",   description: "Re-detect product info and backfill only template fields the file is missing; keep everything already set." },
    { label: "Re-run full setup",    description: "Walk through all prompts again and rewrite config (existing values offered as defaults)." }
  ]
)
```

- **Keep existing** → print a summary of the current config (Product name/one-liner/repo/landing
  URL, Postiz Backend URL, Postiz API key env-var name, whether Voice overrides are set, plus a
  one-line channel count, e.g. "Channels configured: 4") and **STOP**. Write nothing.
- **Merge new findings** → **re-enter at Step 1** (dependency check) before touching anything.
  After Steps 1–2 pass: re-run Step 3 detection, backfill only the `marketing-context.md` template
  fields absent from the existing file (prompting for missing user-choice fields), preserving
  every value already set. Also capture the existing Channels rows from the file and run Step 4b,
  preserving every existing per-channel setting and only backfilling channels/settings absent from
  the file (new channels → schema defaults, AC-4); re-prompt only for genuinely new channels.
  `.agents/product-marketing.md` is re-maintained idempotently by the marketingskills skill
  (Step 4) regardless. Then continue to Step 5 (write) and Step 6.
- **Re-run full setup** → **re-enter at Step 1** (dependency check) before touching anything.
  After Steps 1–2 pass: walk all prompts again with existing values offered as defaults, then
  rewrite via Steps 3–6. Also capture the existing Channels rows from the file and run Step 4b for
  every channel with existing values offered as defaults — the founder may change any.

**Both Merge and Re-run re-enter at Steps 1–2** — the dependency check and Postiz gate always run
before any write, first-run and re-run alike, so a dead or unreachable backend can never be
re-written against.

## Step 1 — Dependency check

Verify **both** dependency plugins/skills are installed before any reachability check:

- `postiz@postiz-agent` (provides the `postiz` skill)
- `marketing-skills@marketingskills` (provides the `product-marketing` skill, among 47 others)

Check for each plugin's presence (e.g. via the plugin/skill listing available in this session). If
either is **missing**, install it idempotently:

```bash
# postiz@postiz-agent
claude plugin marketplace add gitroomhq/postiz-agent
claude plugin install postiz@postiz-agent --scope project

# marketing-skills@marketingskills
claude plugin marketplace add coreyhaines31/marketingskills
claude plugin install marketing-skills@marketingskills --scope project
```

Whether or not an install was needed, ensure the repo's committed `.claude/settings.json` declares
both dependency marketplaces under `extraKnownMarketplaces`. Without this, a teammate's client has
no source for `postiz-agent` / `marketingskills`, gtm's `plugin.json` dependencies are left
unresolved on checkout, and gtm is disabled with a `dependency-unsatisfied` error. Merge these keys
with the native Edit/Write tools (idempotent — preserve existing keys, skip any already present):

```json
{
  "extraKnownMarketplaces": {
    "postiz-agent": {
      "source": { "source": "github", "repo": "gitroomhq/postiz-agent" }
    },
    "marketingskills": {
      "source": { "source": "github", "repo": "coreyhaines31/marketingskills" }
    }
  }
}
```

Project scope records both plugins in `.claude/settings.json` `enabledPlugins` (committed);
together with `extraKnownMarketplaces` above, teammates get the marketplaces registered and both
dependencies auto-resolved on checkout. If either install fails (network, marketplace unreachable, permission
denied), **STOP** with an actionable message naming which plugin failed and the exact commands to
run manually:

> Could not install `<plugin>@<marketplace>`. Run `claude plugin marketplace add <src>` then
> `claude plugin install <plugin>@<marketplace> --scope project` manually, then re-run
> `/gtm:init`. No files were written.

This step writes no config. Only continue to Step 2 once both dependencies are confirmed present.

## Step 2 — Postiz prerequisite gate

Apply `${CLAUDE_PLUGIN_ROOT}/refs/postiz-verify.md` exactly — three conditions, all required:

1. **Resolve the backend URL**, first match wins: (a) the existing `marketing-context.md` Backend
   URL token, when this is a Merge/Re-run re-entry; (b) `POSTIZ_API_URL` env var, if set — used only
   to **seed** the default answer below, never to skip the question; (c) `AskUserQuestion` — the
   founder picks **Cloud default** (`https://api.postiz.com`) or **Self-hosted** (supplies a URL).
   Export the resolved value (`export POSTIZ_API_URL="<resolved>"`) for the rest of this session.
2. **`POSTIZ_API_KEY`** is set and non-empty.
3. **`postiz auth:status`** (with `POSTIZ_API_URL` exported per step 1) reports authenticated.

**STOP with the matching distinct message and write nothing** (AC-1) on any failure — an
unresolved backend URL, a missing `POSTIZ_API_KEY`, a not-authenticated result, or a CLI/connection
error each get their own message per that ref. Do not proceed to Step 3 until this gate passes. The
resolved Backend URL carries forward to Step 5, which persists it as the `marketing-context.md`
token — after that, the token is authoritative for future sessions (see the ref's precedence note).

## Step 3 — Product info detection

Apply `${CLAUDE_PLUGIN_ROOT}/refs/product-detect.md` exactly: a read-only scan for `name`,
`one-liner`, `repo`, and `landing URL` (AC-2). This step writes nothing. Anything unresolved is
carried forward as an interview gap for Step 4. `brand/` is read-only input here — make no changes
under `brand/`.

## Step 4 — Product-marketing context

**Invoke the marketingskills `product-marketing` skill** (from `marketing-skills@marketingskills`,
confirmed installed in Step 1) in-command — do **not** dispatch an agent for this. Seed the
invocation with the Step 3 detection results (including any gaps). The skill owns
`.agents/product-marketing.md`: it checks legacy locations, then either auto-drafts the doc from
README / landing page / `package.json` for the founder to correct, or runs a from-scratch
conversational interview when nothing is detected (AC-2, AC-3). This interview needs no Postiz
calls. On completion, proceed to Step 4b.

## Step 4b — Channel configuration

Apply `${CLAUDE_PLUGIN_ROOT}/refs/channel-config.md` exactly. Preconditions already met by earlier
steps: Step 2 confirmed Postiz auth and exported `POSTIZ_API_URL`; on a fresh run the existing
Channels table is empty; on a Merge/Re-run re-entry, Step 0 has already captured the current
Channels rows.

1. Enumerate via `postiz integrations:list` (AC-1); parse `id`, `name`, `identifier` per channel.
2. For each channel, prompt the founder — one channel at a time — for the four settings
   (Ownership / Voice / Cadence / Content types, AC-2), each pre-seeded with the existing value
   (re-run) or the schema default (fresh run) per the ref. The `reddit` identifier is
   recommended-defaulted to `manual`; any channel the founder skips falls back to the AC-4 default
   `draft`.
3. Collect the answers into the in-memory Channels model that Step 5 renders. This step **writes
   nothing** to final paths — it only gathers values.

Defer to the ref for error handling (transport error → STOP, write nothing; empty-list handling;
malformed-entry skip; the drop-confirmation guard for a previously configured channel that
`integrations:list` no longer returns) rather than re-specifying it here.

## Step 5 — Write gtm config (atomic)

`/gtm:init` must never leave a half-written **gtm config** set. Stage init's own writes under the
session temp dir first, and only move them into place after **every** staged write succeeds.

1. Resolve the staging dir:

   ```bash
   stage="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh")"
   ```

2. Write the following into `$stage`, mirroring the final repo-relative layout:
   - `project/marketing-context.md` — filled from `${CLAUDE_PLUGIN_ROOT}/refs/marketing-context-template.md`
     using the Step 3 detection and Step 3/interview-collected values (product name, one-liner,
     repo, landing URL, the Step 2-resolved Postiz **Backend URL** value, the Postiz API key env-var
     **name** only, empty Voice section), plus the Step 4b Channels model rendered into the
     `## Channels` table (every row fully materialized — no `<...>` placeholder token remains — or
     the empty-table form when no channels exist). No placeholder tokens may remain.
   - `docs-gtm/README.md` — filled from `${CLAUDE_PLUGIN_ROOT}/refs/docs-gtm-readme-template.md`.
   - `docs-gtm/digests/.gitkeep` and `docs-gtm/briefs/.gitkeep` — empty marker files.
   - `gtm-plugin-root` — the resolved `${CLAUDE_PLUGIN_ROOT}` value (this session's), single line.

3. **Verify `.agents/product-marketing.md` exists** (Step 4's output) **before finalizing anything**
   — this gates the move in sub-step 4 below:

   ```bash
   [ -f ".agents/product-marketing.md" ] && echo "PMM_DOC=yes" || echo "PMM_DOC=no"
   ```

   If `PMM_DOC=no`, delete the staging area and **STOP** — the product-marketing context doc
   (`.agents/product-marketing.md`) is missing:

   ```bash
   rm -rf "$stage"
   ```

   > The marketingskills `product-marketing` skill did not produce `.agents/product-marketing.md`.
   > init's own config writes have been discarded — nothing was finalized. Re-run `/gtm:init` once
   > the skill can complete.

   Because this check runs **before** sub-step 4 moves anything into place, the "discarded" claim
   holds: at this point only `$stage` exists on disk, and deleting it truly leaves the repo
   untouched. The atomic guarantee covers only init's **own** writes (`marketing-context.md`, the
   `docs/gtm/` scaffold, the `.gtm-plugin-root` marker) — `.agents/product-marketing.md` is the
   skill's own interactive output from Step 4, accepted as-is and verified here, not staged by
   init.

4. Only after **all** of the above are written successfully and PMM_DOC=yes, move them into their
   final paths (same-filesystem rename where possible). `marketing-context.md` moves **last** — its
   presence is what Step 0's re-init guard checks, so it is the natural commit point: every other
   path lands first, and only once they've all succeeded does the guard-visible file appear.

   ```bash
   mkdir -p .claude/project docs/gtm/digests docs/gtm/briefs
   mv "$stage/docs-gtm/README.md" docs/gtm/README.md
   mv "$stage/docs-gtm/digests/.gitkeep" docs/gtm/digests/.gitkeep
   mv "$stage/docs-gtm/briefs/.gitkeep" docs/gtm/briefs/.gitkeep
   mv "$stage/gtm-plugin-root" .claude/.gtm-plugin-root
   mv "$stage/project/marketing-context.md" .claude/project/marketing-context.md
   rm -rf "$stage"
   ```

   A failure while **staging** (sub-steps 1–2) or at the **PMM_DOC gate** (sub-step 3) leaves every
   final path untouched — nothing has moved yet. A failure **mid-move** here (a `mv` fails partway)
   can leave some final paths written and others not; it is not silently rolled back. Report the
   failure and STOP — re-running `/gtm:init` (Step 0's Merge/Re-run paths) heals a half-finalized
   state, since only `marketing-context.md` marks completion and it is the last thing written.

5. Ensure gitignore entries (idempotent append, mirror sdlc's Step 4e) — `.tmp/` (agent scratch)
   and `.claude/.gtm-plugin-root` (gitignored, unlike sdlc's committed marker — it is a per-session
   machine-absolute cache):

   ```bash
   if [ ! -f .gitignore ] || ! grep -qxF '.tmp/' .gitignore; then
     printf '\n# agent scratch — gtm plugin temp files (auto-cleaned, never commit)\n.tmp/\n' >> .gitignore
   fi
   if [ ! -f .gitignore ] || ! grep -qxF '.claude/.gtm-plugin-root' .gitignore; then
     printf '\n# gtm plugin-root marker — per-session cache, never commit\n.claude/.gtm-plugin-root\n' >> .gitignore
   fi
   ```

## Step 6 — Post-init checklist

Print a summary:

> **Files written:**
> - `.claude/project/marketing-context.md` — gtm's operational config (product basics, the Postiz
>   Backend URL, the Postiz API key env-var name, empty Voice overrides, the per-channel Channels
>   table).
> - `.agents/product-marketing.md` — the marketingskills canonical product-context doc.
> - `docs/gtm/README.md`, `docs/gtm/digests/.gitkeep`, `docs/gtm/briefs/.gitkeep` — the marketing
>   working-directory scaffold.
> - `.claude/.gtm-plugin-root` (gitignored) — per-session plugin-root cache.
>
> **Channels configured:** N (ownership/voice/cadence/content-types per channel) — graduate a
> channel from `draft` to `auto` by re-running `/gtm:init` and changing its ownership.
> (Note any channel dropped on a re-run via the drop-confirmation guard here.)
>
> **Keep this environment variable set** for every future gtm session: `POSTIZ_API_KEY`. Only its
> **name** was persisted to disk — never the value. The Postiz backend URL now lives in
> `marketing-context.md` (not a secret) — gtm commands export it as `POSTIZ_API_URL` for the
> `postiz` CLI automatically; you don't need to keep it set yourself.
>
> **To commit the foundation** (AC-5):
> ```bash
> git add .claude/project/marketing-context.md .agents/product-marketing.md docs/gtm .gitignore
> git commit -m "chore(gtm): bootstrap marketing foundation via /gtm:init"
> ```
>
> **Next, under Epic [NA-2](https://whimzylive.atlassian.net/browse/NA-2):** this foundation
> unblocks **NA-5, NA-6, NA-7, NA-8** (KPI metric+source setup, engagement listening, pulse,
> launch) and **NA-11**. Those remain unblocked-not-yet-configured; channel ownership/voice/cadence
> config (NA-4) is now written by this run — see **Channels configured** above.

## Final — Release session

After everything above is complete (success, or a terminal STOP surfaced to the user), run this as
your very last action:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh"
```

It prints the completion signal an automation worker watches for. Outside such a worker
(`GTM_SESSION_KEY` unset) it is a silent no-op — always safe to run.
