---
id: awk-fnr-nr-empty-first-file-miscounts
agent: [platform-engineer]
trigger: [awk FNR==NR two-file idiom, empty first input file, artifact-contract.sh fixture with zero items, awk file-boundary detection]
rule: When testing an awk `FNR==NR{...}` two-file idiom, never use a fixture whose first file extracts to zero records — NR does not advance for an empty file, so its first record misreads as file 1's.
evidence: [NA-88]
uses: 0
status: active
---

## Why

A C7 regression fixture selected `--fence 1` on a fenced block with no heading/field/literal
content, so `tpl_items` was genuinely empty (0 lines). `tools/sdlc-analyser/artifact-contract.sh`'s
`compare_awk` distinguishes template vs artifact rows with `FNR == NR`, the standard awk idiom — but
when the first file has zero lines, `NR` never advances past 0 while reading it, so the _first line
of the second file_ satisfies `FNR==NR` (both 1) and gets misclassified as a template row. Always
pick fixtures with at least one real contract item on the template side; an all-placeholder or
all-prose fixture that extracts to nothing will silently corrupt the comparison instead of failing
loud.
