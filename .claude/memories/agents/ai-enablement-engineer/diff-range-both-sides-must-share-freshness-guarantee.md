---
id: diff-range-both-sides-must-share-freshness-guarantee
agent: [ai-enablement-engineer]
trigger: [git diff base...branch bare local ref, spec's own worked bash example mixes fetched and bare refs]
rule: '`git diff --name-only "<BASE-BRANCH>...$STORY_BRANCH"` (bare local branch name on the left) is checkout-dependent.'
evidence: [NA-52]
uses: 0
status: active
---
