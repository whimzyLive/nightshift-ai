# gtm — GTM marketing plugin

The marketing counterpart to the `sdlc` plugin. `/gtm:init` bootstraps a version-controlled
marketing foundation for this repo — gating on Postiz reachability, detecting product info, and
invoking the marketingskills `product-marketing` skill — before any channel, KPI, engagement, or
launch configuration exists.

## Install
    /plugin marketplace add <path-or-git-url-to-this-repo>
    /plugin install gtm@nightshift

Installing `gtm@nightshift` also pulls its two cross-marketplace dependencies (below) via the
marketplace allowlist.

## Consumer repo requirements
- `.claude/project/marketing-context.md` — gtm's operational config, written by `/gtm:init`
  (auto-loaded each session by this plugin's SessionStart hook).
- `.agents/product-marketing.md` — the marketingskills canonical product-context doc, created and
  maintained by the `product-marketing` skill (also written by `/gtm:init`, Step 4).
- Add `.claude/.gtm-plugin-root` to the repo's `.gitignore` (done automatically by `/gtm:init`).

## Plugin-path resolution (`.claude/.gtm-plugin-root`)
`${CLAUDE_PLUGIN_ROOT}` is only available to Claude Code hooks and slash commands — it is **not**
injected into subagents. Since the `product-marketing-manager` agent needs to read bundled refs
and run bundled scripts, the SessionStart hook (which does have the variable) writes the resolved
absolute plugin root to `.claude/.gtm-plugin-root` in the consumer repo each session. The agent
reads that one-line marker from cwd and substitutes it wherever its instructions reference
`${CLAUDE_PLUGIN_ROOT}`. The file is a regenerated per-session cache — it is **gitignored**
(deliberate divergence from sdlc's committed `.sdlc-plugin-root`; `/gtm:init` adds the entry for
you).

## Dependencies
- **`postiz@postiz-agent`** — **auto-installed.** Declared as a cross-marketplace dependency
  (marketplace `postiz-agent`, source `gitroomhq/postiz-agent`), so `/plugin install gtm@nightshift`
  reuses an existing install or pulls it. Provides the `postiz` skill wrapping the `postiz` npm CLI
  (`auth:status`/`auth:login`, `posts:create`, `upload`, `integrations`, `analytics`). All Postiz
  operations across this plugin — init's reachability gate and every downstream publish/upload/
  analytics action — go through this skill; gtm never hand-rolls HTTP against Postiz.
- **`marketing-skills@marketingskills`** — **auto-installed.** Declared as a cross-marketplace
  dependency (marketplace `marketingskills`, source `coreyhaines31/marketingskills`). Provides 47
  skills; `/gtm:init` invokes `product-marketing` directly, and the `product-marketing-manager`
  agent additionally uses `launch`, `content-strategy`, and `copywriting`.
- **No `superpowers` dependency** — no gtm command or agent invokes a superpowers skill.
- **No dependency on the `sdlc` plugin** — every shared script gtm needs (`session-key.sh`,
  `tmp-dir.sh`, `cleanup-tmp.sh`, `session-complete.sh`) is vendored into `plugins/gtm/scripts/`,
  so gtm is fully standalone.

## Env-var contract (Postiz)

The `postiz` CLI reads its backend URL from the `POSTIZ_API_URL` environment variable and its API
key from `POSTIZ_API_KEY`. gtm splits these differently by sensitivity:

| Value | Where it lives | Persisted? |
| ----- | --------------- | ---------- |
| Postiz backend URL | `.claude/project/marketing-context.md` (Postiz → `Backend URL`) | **Yes** — a config token, not a secret. Chosen at `/gtm:init` via `AskUserQuestion`: **cloud default** (`https://api.postiz.com`) or a **self-hosted** URL you supply. Commands that invoke the `postiz` CLI export it as `POSTIZ_API_URL` from this token. |
| Postiz API key | environment only (`POSTIZ_API_KEY`) | **Never** — only the env-var **name** `POSTIZ_API_KEY` is persisted; the key value must stay in your shell/`.env`, never written to disk. |

An already-set `POSTIZ_API_URL` env var, if present at `/gtm:init` time, seeds the default answer
to the backend-URL question — it does not skip it. After init, the `marketing-context.md` token is
authoritative; later changes to the env var no longer take effect unless you re-run `/gtm:init`.
