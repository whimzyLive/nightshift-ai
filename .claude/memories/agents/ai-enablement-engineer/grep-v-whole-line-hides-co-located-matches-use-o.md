---
id: grep-v-whole-line-hides-co-located-matches-use-o
agent: [ai-enablement-engineer]
trigger: ["no stray placeholder" check, grep -v on whole lines, token-by-token scan needed]
rule: "`grep -v '<pattern>'` on whole lines silently hides any OTHER match that happens to share a line with the excluded pattern."
evidence: [NA-4]
uses: 0
status: active
---
