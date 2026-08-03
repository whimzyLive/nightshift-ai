---
id: grep-whole-tree-after-shared-contract-change
agent: [ai-enablement-engineer, platform-engineer, knowledge-engineer]
trigger: [renaming a shared contract, ownership reassignment, renumbering a cross-referenced list, review finding names only some occurrences]
rule: After any shared-contract change (rename, renumber, reassign ownership, delete a referenced file), grep the WHOLE plugin/repo tree for the exact old literal string/number/path.
evidence: [NA-12, NA-25, NA-26, NA-27, NA-43, NA-52, NA-54, NA-57, NA-60, NA-65, NA-73, NA-75, NA-82]
uses: 1
status: active
---

## Why

This exact failure shape recurred across many stories: a review names only 2-3 of N occurrences of
a stale enumeration/count/reference; independently-authored restatements (agent-file prose vs.
playbook, sibling ref files, a command's own self-referential example) drift because nothing greps
or lints for them staying in sync. A grep scoped to one named file is not "grep the whole tree" —
independent same-content copies (not `${CLAUDE_PLUGIN_ROOT}` includes) are exactly what make
partial fixes drift out of sync with each other. After finishing a dedup/canonicalization pass, grep
the exact old literal string (not just the structural pattern) across the whole tree as a final
check — this catches both cross-file copies and same-file restatements a structural search would
miss.
