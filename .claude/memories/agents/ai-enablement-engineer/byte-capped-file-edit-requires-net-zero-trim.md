---
id: byte-capped-file-edit-requires-net-zero-trim
agent: [ai-enablement-engineer]
trigger: [editing commands/loop.md or refs/loop-modes.md, editing the principal-engineer or qa-engineer playbook, a byte-cap test failing after a correctness fix]
rule: When a correctness edit adds bytes to a byte-capped instruction file/pair, offset it by trimming existing prose in the SAME capped file/pair — a byte-cap test failure is not optional to fix.
evidence: [e02d9a1b06]
uses: 0
status: active
---

## Why

`loop.md`, `loop-modes.md`, and the two playbooks are pinned by
`loop-decision-budget.test.sh` at hard byte ceilings (individual + paired), with headroom often
under 100 B. A behaviourally-necessary fix (e.g. binding a previously-undefined variable, adding
a per-path guard) routinely adds more bytes than the file's remaining headroom. The correct
response is NOT to raise the pin — it is to tighten wording elsewhere in the same capped
file/pair (shorten a cross-reference, drop a redundant restatement, compress a rationale aside)
until the net byte delta fits, then re-run the byte-cap test to confirm. Never leave a byte-cap
gate red or silently bump its constant.
