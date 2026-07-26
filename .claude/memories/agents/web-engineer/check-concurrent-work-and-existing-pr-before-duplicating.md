---
id: check-concurrent-work-and-existing-pr-before-duplicating
agent: [web-engineer]
trigger: [concurrent process using the same Claude-Session ID on the same branch, checking for a duplicate PR]
rule: 'When a concurrent process independently pushed overlapping commits to the same branch, diff `HEAD` against your own files first, and `gh pr list --head <branch>` before creating a new PR.'
evidence: [PR#97]
uses: 0
status: active
---
