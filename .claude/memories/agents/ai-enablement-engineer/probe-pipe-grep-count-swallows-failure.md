---
id: probe-pipe-grep-count-swallows-failure
agent: [ai-enablement-engineer]
trigger: [counting a probe script's output lines via a pipe, grep -c . || true idiom, wiring a new gh/CLI probe into a decision script]
rule: A probe piped into `grep -c . || true` to count lines prints 0 on ANY failure (non-zero exit, empty stdout) — indistinguishable from a legitimate zero.
evidence: [e02d9a1b06]
uses: 0
status: active
---

## Why

`cur="$(probe.sh ... | grep -c . || true)"` was meant to count non-empty lines, but `probe.sh`
runs `set -euo pipefail` and can exit non-zero (auth/network/rate-limit) — its status is lost
through the pipe, `grep -c .` on empty input prints `0`, and `|| true` swallows the rest. A hard
probe failure becomes byte-identical to "genuinely zero results", which is unsafe wherever the
zero count feeds a decision (e.g. `sdlc:loop`'s clean/auto-merge path). Fix: capture the probe's
own stdout and status FIRST (`out="$(probe.sh ...)" || handle-failure`), THEN count lines from
the captured `$out` — never count directly off the probe's pipe output.
