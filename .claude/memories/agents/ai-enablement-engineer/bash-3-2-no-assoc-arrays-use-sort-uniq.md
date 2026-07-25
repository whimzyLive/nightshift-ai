---
id: bash-3-2-no-assoc-arrays-use-sort-uniq
agent: [ai-enablement-engineer]
trigger: [plugins/sdlc/scripts bash script, declare -A, duplicate-key detection, globstar]
rule: This repo's `/bin/bash` resolves to macOS-shipped 3.2.57 (no `declare -A`, no `mapfile`, no `globstar`).
evidence: [NA-73, NA-62]
uses: 0
status: active
---

## Why

Both `collect-memory.sh` and `check-frontmatter.sh` needed rule-`id` uniqueness detection without
associative arrays — solved with the sort/uniq idiom, no dictionary needed. Separately, a script
using `shopt -s globstar; files=(plugins/**/*.md)` fails outright on this bash (invalid shell option
name errors on every invocation) — `find plugins -type f -name '*.md' | wc -l` has no bash-version
dependency and behaves identically. Any future `plugins/sdlc/scripts/*.sh` needing a recursive glob
should default to `find` unless bash>=4 on every target shell (including contributor macOS laptops)
is independently confirmed — a CI-only script would mask this since GitHub's Ubuntu runners ship a
newer bash.
