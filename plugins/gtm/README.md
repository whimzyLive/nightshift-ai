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

`/gtm:init`'s reachability gate (and every downstream Postiz action) requires two environment
variables, read from the environment at run time:

| Env var | Purpose |
| ------- | ------- |
| `POSTIZ_API_URL` | Postiz backend URL (cloud or self-hosted) |
| `POSTIZ_API_KEY` | API key for authentication |

**Secret hygiene:** only the env-var **names** (`POSTIZ_API_URL`, `POSTIZ_API_KEY`) are persisted
to `.claude/project/marketing-context.md` — the actual URL and key **values live in the
environment and are never written to disk**.
