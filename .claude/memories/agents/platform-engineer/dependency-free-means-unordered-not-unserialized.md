---
id: dependency-free-means-unordered-not-unserialized
agent: [platform-engineer]
trigger: [parallel dispatch review shorthand, sequential-only exception wording, owner ruling reverses a numbered slot]
rule: When a review defines a domain-agent scheduling property with a precise causal justification ("it consumes no artifacts from other domain agents and nothing consumes its"), reword every occurren.
evidence: [NA-12]
uses: 0
status: active
---

## Why

An owner ruling reversed an agent from a numbered serial Phase-3 slot to a dependency-free
unordered mention — every file that had been renumbered up needed renumbering back down, with the
agent pulled entirely out of the numbered sequence (never even a placeholder "Phase N (parallel)"
slot, since a numbered slot visually implies "waits for N-1"). The corrected rule still requires
"sequential only — never two domain agents at once" universally (the git single-branch/worktree
constraint doesn't go away) — the exception is about ORDER, not concurrency. After any such revert,
grep the whole tree for dangling old-number references, not just the renumbered files.
