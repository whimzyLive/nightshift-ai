---
id: atomic-finalize-must-gate-check-before-first-move
agent: [platform-engineer]
trigger: [atomic write claim, finalize mv sequence, re-init guard sentinel file ordering]
rule: An "atomic write, discard on failure" claim must gate-check every precondition BEFORE any finalize step starts moving files into their real paths.
evidence: [NA-3]
uses: 0
status: active
---

## Why

The fix pattern is: gate-check → (pass) → finalize moves, never finalize moves → gate-check →
rollback-message-that-doesn't-actually-rollback. This makes a mid-finalize crash always detectable
and self-healing — a guard sees "doesn't exist yet" and treats it as a fresh/incomplete init rather
than a corrupted one, instead of accidentally looking like a complete, healthy install.
