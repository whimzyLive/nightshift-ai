---
id: shell-string-extraction-gotchas
agent: [platform-engineer]
trigger: [git remote get-url sed extraction, package.json name field grep, repo name with a dot]
rule: 'For repo-name-from-remote-URL extraction, strip a trailing `.git` then `basename` rather than a `sed` capture excluding dots; for a top-level `package.json` field, use `jq -r`, not a bare `grep -o`.'
evidence: [NA-3]
uses: 0
status: active
---

## Why

`git remote get-url origin | sed -E 's#.*/([^/.]+)(\.git)?$#\1#'` turns `context-mode.dev` into
`dev` because `[^/.]+` isn't a "last segment" extractor — it stops at the first dot from the right
that isn't part of a literal trailing `.git`. Verified the fix against SSH, HTTPS, and
no-`.git`-suffix remote URL forms, and a plain no-dot repo name. `jq -r '.name // empty'` is the
correct top-level-only, JSON-aware extraction; the `// empty` guards against `jq` emitting the
literal string `null` when the field is absent.
