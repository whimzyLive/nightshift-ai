---
id: probe-once-gate-both-branches-on-same-boolean
agent: [ai-enablement-engineer]
trigger: [worktree-setup.sh admits local-or-remote branch, body always fetches origin unconditionally]
rule: A "two-branch admits local-OR-remote, but the body always fetches/merges origin unconditionally" bug is fixed by probing existence (`git ls-remote --exit-code --heads origin "$BRANCH"`) into a b.
evidence: [NA-27]
uses: 0
status: active
---
