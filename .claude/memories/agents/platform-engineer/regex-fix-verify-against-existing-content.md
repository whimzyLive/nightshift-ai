---
id: regex-fix-verify-against-existing-content
agent: [platform-engineer]
trigger: [review's own suggested regex fix, tightening a lint detector, worktree wrong-branch alternative recovery]
rule: A review finding's own suggested regex fix can be under-verified.
evidence: [NA-3]
uses: 0
status: active
---

## Why

A proposed single-quoted ERE `[A-Za-z]:\\` (meant to catch `C:\Users\...`) broke on pre-existing,
unrelated prose containing an escaped-newline-in-a-doc-string shape (`"...exactly:\n  Status: ..."`)
— fixed by requiring the char before the drive letter be a non-letter:
`(^|[^A-Za-z])[A-Za-z]:\\`. Separately, a fix that adds new legitimate content can itself trip an
unrelated existing lint check (`git@github.com` looks like PII to a naive `word@word.tld` email
regex) — extend the existing allowlist rather than weakening the base check. Always re-run the full
lint/verification command after a "surgical" one-line regex fix, even when it looks obviously
correct in isolation and matches the review's own snippet. (Unrelated worktree note: when the wrong
branch is checked out elsewhere and a ff-only merge won't free it, detaching the OTHER checkout
`git -C <shared-path> checkout --detach` then checking out the target branch locally is a valid
alternative to `git merge --ff-only`, safe only when that other checkout is clean and at the same
commit.)
