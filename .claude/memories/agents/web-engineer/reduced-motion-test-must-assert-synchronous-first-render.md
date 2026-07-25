---
id: reduced-motion-test-must-assert-synchronous-first-render
agent: [web-engineer]
trigger: [waitFor masks a post-mount-effect bug, always-live enter transition reduced-motion test]
rule: Write a reduced-motion regression test for an always-live (non-viewport-gated) enter animation WITHOUT `waitFor`, asserting the first synchronous render immediately after `render()`.
evidence: [NA-69]
uses: 0
status: active
---

## Why

Proved the assertion actually catches the regression by temporarily reverting the fix and
re-running: it failed exactly as expected before restoring the fix.
