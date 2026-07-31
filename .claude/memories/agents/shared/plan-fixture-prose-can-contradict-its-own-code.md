---
id: plan-fixture-prose-can-contradict-its-own-code
agent: [platform-engineer, ai-enablement-engineer, web-engineer]
trigger: [plan gives verbatim fixture content next to verbatim code, TDD red phase fails for an unexpected reason, path resolution mismatch in a plan-supplied fixture]
rule: When a plan's illustrative fixture-content prose conflicts with the verbatim code it specifies for the same feature, trust the code contract (verify via the RED-phase test failure) over the prose, and fix the fixture — do not paste the prose literally.
evidence: [NA-89]
uses: 1
status: active
---

## Why

NA-89's Task 1.1 told the executor to write `list.txt` containing the literal string
`__tests__/fixtures/rtk-coverage/corpus.jsonl`, described as "resolved relative to
`tools/sdlc-analyser/`" — but the verbatim `read_corpus_list` code given two steps later resolves
each entry relative to the **list file's own directory** (`fixtures/rtk-coverage/`). Pasting the
prose's literal string produced a doubled path and a RED failure that read as "missing corpus
file", not "script doesn't exist" — the expected RED reason for that step. TDD's mandate to verify
the failure reason (not just that it failed) is what surfaces this class of plan bug: a plan author
writing English and code in the same task can let them drift, and the code — being the thing
actually executed and unit-tested — is the more reliable of the two to trust.
