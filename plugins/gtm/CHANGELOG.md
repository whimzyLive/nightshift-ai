## 0.5.1 (2026-07-20)

### 🚀 Features

- **nx-release:** NA-63 wire nx release config + register plugins ([8f89968](https://github.com/whimzyLive/nightshift-ai/commit/8f89968))
- **gtm:** add /gtm:docs audit command, docs-auditor agent, and rubric ([93c24e9](https://github.com/whimzyLive/nightshift-ai/commit/93c24e9))
- **gtm:** NA-6 content-writer agent + voice rules + /gtm:site command ([104a61c](https://github.com/whimzyLive/nightshift-ai/commit/104a61c))
- **gtm:** set up KPI metric and source in init (NA-5) ([9852c74](https://github.com/whimzyLive/nightshift-ai/commit/9852c74))
- **gtm:** add per-channel ownership picker to /gtm:init ([8f46a15](https://github.com/whimzyLive/nightshift-ai/commit/8f46a15))
- **gtm:** persist Postiz backend URL as marketing-context token ([#43](https://github.com/whimzyLive/nightshift-ai/issues/43))
- **gtm:** add plugin README ([d6ca96b](https://github.com/whimzyLive/nightshift-ai/commit/d6ca96b))
- **gtm:** add product-marketing-manager agent definition ([6d3d674](https://github.com/whimzyLive/nightshift-ai/commit/6d3d674))
- **gtm:** add /gtm:init command ([2fbfc0e](https://github.com/whimzyLive/nightshift-ai/commit/2fbfc0e))
- **gtm:** add init refs (postiz gate, product detection, templates) ([1d71eb2](https://github.com/whimzyLive/nightshift-ai/commit/1d71eb2))
- **gtm:** add SessionStart/SessionEnd hooks ([25cae2f](https://github.com/whimzyLive/nightshift-ai/commit/25cae2f))
- **gtm:** add plugin manifest and marketplace registration ([9ae5781](https://github.com/whimzyLive/nightshift-ai/commit/9ae5781))
- **gtm:** vendor session lifecycle scripts ([672bb13](https://github.com/whimzyLive/nightshift-ai/commit/672bb13))

### 🩹 Fixes

- **gtm:** NA-62 PR#131 review — restore postiz-verify.md wrapped-ordinal split ([#131](https://github.com/whimzyLive/nightshift-ai/issues/131))
- **gtm:** resolve docs-audit base branch dynamically, fix rubric polarity, and scope PR-ID extraction ([#103](https://github.com/whimzyLive/nightshift-ai/issues/103))
- **gtm:** repair docs-audit idempotency guard and stale cross-refs ([167c898](https://github.com/whimzyLive/nightshift-ai/commit/167c898))
- **gtm:** NA-6 sync plan to 1b restructure; scope FAIL-report variants ([b0ab145](https://github.com/whimzyLive/nightshift-ai/commit/b0ab145))
- **gtm:** NA-6 workflow-review fixes — verdict-only gate, up-front re-run guard, marker bootstrap, council contract ([185b436](https://github.com/whimzyLive/nightshift-ai/commit/185b436))
- **gtm:** NA-6 loop review fixes — agent persistence boundary, precondition probe, FAIL-path report ([fa78a1a](https://github.com/whimzyLive/nightshift-ai/commit/fa78a1a))
- **gtm:** NA-6 generalise gate FAIL consequences for shared-ref consumers ([53aef9e](https://github.com/whimzyLive/nightshift-ai/commit/53aef9e))
- **gtm:** NA-5 review fixes — probe auth ordering, keep-path fallback, template hygiene ([48b0b39](https://github.com/whimzyLive/nightshift-ai/commit/48b0b39))
- **gtm:** NA-5 make endpoint probe jq usage conditional (review) ([c8c4652](https://github.com/whimzyLive/nightshift-ai/commit/c8c4652))
- **gtm:** harden channel picker findings F1-F10 (NA-4 review-fix) ([2bbebf6](https://github.com/whimzyLive/nightshift-ai/commit/2bbebf6))
- **gtm:** close template-fence leak gate and stale-story wording ([f659c88](https://github.com/whimzyLive/nightshift-ai/commit/f659c88))
- **gtm:** stop leaking init-protocol prose into the rendered template ([170c013](https://github.com/whimzyLive/nightshift-ai/commit/170c013))
- **gtm:** address Copilot review on init robustness ([77b853d](https://github.com/whimzyLive/nightshift-ai/commit/77b853d))
- **gtm:** gate /gtm:init finalize on PMM doc check, fix portability-lint scope ([2289e76](https://github.com/whimzyLive/nightshift-ai/commit/2289e76))

### ❤️ Thank You

- Rushi Patel @whimzyLive
