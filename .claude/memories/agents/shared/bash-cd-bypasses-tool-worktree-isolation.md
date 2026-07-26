---
id: bash-cd-bypasses-tool-worktree-isolation
agent: [web-engineer, platform-engineer]
trigger: [git worktree dispatch, cd into shared checkout path, accidental write to wrong checkout]
rule: The Write/Edit tools refuse to touch files outside your assigned worktree even if you `cd` there via Bash, but Bash itself does not enforce this.
evidence: [NA-16, NA-3]
uses: 0
status: active
---
