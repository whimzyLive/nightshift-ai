---
id: reference-artifact-backtick-path-span-shifts-contract-position
agent: [ai-enablement-engineer]
trigger: [writing a minimal reference artifact for artifact-contract.sh, D12 tier-1 content-contract gate, CONTRACT_MATCH=false with everything after item 1-2 missing]
rule: When authoring a reference artifact for artifact-contract.sh, avoid backtick-quoted path spans in free prose — each becomes an extra literal item and shifts positional alignment.
evidence: [NA-87]
uses: 0
status: active
---

## Why

Prose describing "emitted from the post-change `writing-specs/SKILL.md` template" reads as
harmless commentary, but `artifact-contract.sh`'s extractor classifies any backtick span
containing `/` with no whitespace as a `literal` item regardless of where it sits — including
inside ordinary sentences, not just fenced code. Since the diff is positional, one uncounted-for
literal early in the file pushes every heading after it out of alignment, and the tool reports
them all as `CONTRACT_MISSING` even though the content is correct. Either drop the backticks
around any file-path mention in reference-artifact prose, or account for it as a deliberate extra
`literal` item at that exact position.
