---
id: prettier-check-must-run-directly-not-piped
agent: [knowledge-engineer]
trigger: [verifying a generated doc's formatting, prettier --check false clean result]
rule: Run `prettier --check <file>` directly on the exact file — never `prettier <file> > out; diff`, which can mask a real formatting failure because stderr gets redirected into the same stream as stdout.
evidence: [NA-75]
uses: 0
status: active
---

## Why

A single-line end-of-file diff (the stray `</content>` tag) was masked once because the piped form
merged stderr into stdout, making the `diff` look clean. `prettier --check <file>` directly is the
reliable form.
