---
id: sync-commit-subject-not-proof
agent: [knowledge-engineer]
trigger: [reviewing a prior sync commit, trusting a docs regen commit message]
rule: A `docs(docs): sync ...` commit's subject is a signal of where to look, not proof its regen was correct — independently re-derive and re-verify the touched row against its source.
evidence: [PR#155]
uses: 0
status: active
---

## Why

An audit re-run independently re-extracted the touched source's first paragraph and diffed it
against the page body, rather than trusting a prior standalone sync commit's message — the
re-verification is what actually confirms correctness.
