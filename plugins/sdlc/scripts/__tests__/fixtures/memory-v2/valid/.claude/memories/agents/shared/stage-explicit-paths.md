---
id: stage-explicit-paths
agent: [web-engineer, qa-engineer]
trigger: [git staging, commit]
rule: When staging changes for a commit, list explicit paths rather than using git add -A.
evidence: [PR#137, a1b2c3d]
uses: 2
status: active
---
