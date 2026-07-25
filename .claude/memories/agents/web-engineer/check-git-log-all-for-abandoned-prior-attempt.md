---
id: check-git-log-all-for-abandoned-prior-attempt
agent: [web-engineer]
trigger: [about to hand-author a config/CSS file from scratch, prior unmerged branch may have built it already]
rule: '`git log --all -- <path>` is a cheap way to check whether a "new" file about to be created was already built (and abandoned/orphaned) on some other branch, before hand-authoring it from scratch.'
evidence: [b00e9fc9]
uses: 0
status: active
---
