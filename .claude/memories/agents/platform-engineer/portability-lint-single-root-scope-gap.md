---
id: portability-lint-single-root-scope-gap
agent: [platform-engineer]
trigger: [tools/portability-lint.sh, new plugin unscanned, lint hardcoded to one root]
rule: When adding a second plugin root (or any new scanned unit) to a shared lint/CI script, check whether the script has a single hardcoded root var.
evidence: [NA-3, NA-63, NA-90, NA-82]
uses: 2
status: active
---

## Why

`tools/portability-lint.sh` had `../plugins/sdlc` hardcoded as its only scan root — adding
`plugins/gtm` made it a silent no-op for the new plugin (and later, for `tools/`-based additions too
— `bash tools/portability-lint.sh` only scans `plugins/**`, so a green run says nothing about a new
file under `tools/`). When a review finding says "root hardcoded to X, should scan all Y," also
check whether any of the script's OTHER checks assume a single root implicitly beyond the obvious
`root=` var — collapsing everything into one blind per-unit loop can over-scan a check that should
run once, not once per unit.
