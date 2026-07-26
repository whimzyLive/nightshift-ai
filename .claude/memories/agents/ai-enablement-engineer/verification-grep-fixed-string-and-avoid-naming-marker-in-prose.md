---
id: verification-grep-fixed-string-and-avoid-naming-marker-in-prose
agent: [ai-enablement-engineer]
trigger: [plan verification grep matches its own explanatory prose, grep -c on a dotted path]
rule: A plan's structural verification grep can accidentally match its own explanatory prose.
evidence: [NA-6]
uses: 0
status: active
---

## Why

`grep -c '.gtm-plugin-root'` (unescaped dot) matched any char before the token, counting unrelated
prose; and a sentence merely explaining "there is no `.claude/.gtm-plugin-root` resolver block here"
trips the count. Always run the check for real rather than eyeballing the regex.
