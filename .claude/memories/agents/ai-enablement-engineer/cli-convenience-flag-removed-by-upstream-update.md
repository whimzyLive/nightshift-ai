---
id: cli-convenience-flag-removed-by-upstream-update
agent: [ai-enablement-engineer]
trigger: [gh pr merge --yes removed, third-party CLI flag no longer supported, belt-and-suspenders flag]
rule: Don't pass a third-party-CLI convenience flag a call doesn't strictly need.
evidence: [NA-45]
uses: 0
status: active
---

## Why

`auto-merge-pr.sh` passed `--yes` to `gh pr merge`, a flag gh ≥2.90 removed entirely
(`unknown flag: --yes`). `gh pr merge <pr> <method>` (no `--yes`) is already non-interactive once
the merge method is given explicitly — dropping `--yes` restored working behavior with zero change
to the hang-avoidance guarantee the flag was originally added for. This established
`plugins/sdlc/scripts/__tests__/<name>.test.sh` as the pattern for future script regression tests:
self-runnable via bare `bash`, mock external CLIs by writing tiny wrapper scripts into a `mktemp -d`
dir prepended onto `PATH`, assert on stdout contract + exit code.
