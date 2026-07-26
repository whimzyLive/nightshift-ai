---
id: cross-file-verbatim-phrase-can-line-wrap-defeating-grep
agent: [ai-enablement-engineer]
trigger: [verification grep expects a multi-word phrase, prose hard-wraps a locked phrase across two lines]
rule: Any cross-file verbatim-string verification gate needs the asserted phrase kept on ONE physical line at every restatement site.
evidence: [NA-5, NA-26, NA-52]
uses: 0
status: active
---

## Why

Recurred across multiple stories: a spec's exact multi-word token ("Custom command"), a plan's
"read each directory guide it lists" phrase, and a registry's `source-of-truth` string all failed a
`grep -onE` check in exactly one of several files because prose line-wrap split the phrase across
two source lines. Re-wrap any option/enum/locked-phrase sentence onto one physical line rather than
treating a partial grep match as evidence the content itself is wrong. Separately: read a plan's
own "Expected: none" grep result as "none INTRODUCED BY THIS STORY's edits," not "the tree starts
clean" — this repo's plugin already carries plenty of pre-existing unrelated matches in files the
story never touches; diff the flagged line numbers against your own edited spans before treating a
non-empty grep as a failure.
