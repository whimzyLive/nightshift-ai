---
id: reference-integrity-git-log-precedence-check
agent: [knowledge-engineer]
trigger: [reference-integrity tier, source: glob verification, related-adrs staleness check]
rule: Verify a how-to/integration-guide page's `source:`-globbed file(s) and any `related-adrs:` entry each pre-date the page's own last commit via `git log -1 --format=%cI`, not by eyeballing.
evidence: [PR#155]
uses: 0
status: active
---

## Why

Also confirm every backtick-quoted repo-relative path across narrative pages resolves at
`origin/<BASE-BRANCH>` via `git cat-file -e`. This tier is only clean once both checks are done
mechanically — zero corrections/flags is a real clean-scan result, not an assumption.
