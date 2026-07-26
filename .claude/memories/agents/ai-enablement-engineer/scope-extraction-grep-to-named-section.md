---
id: scope-extraction-grep-to-named-section
agent: [ai-enablement-engineer]
trigger: [finding-ID extraction from PR body, grep whole PR body instead of a specific section]
rule: When a convention defines a specific section for a structured extraction target, scope the extraction with a `sed -n` range over the target heading before grepping.
evidence: [NA-7]
uses: 0
status: active
---

## Why

A finding-ID grep (`- ` followed by a backtick-quoted kebab token) also matched the `## Summary`
section's own bullets, since group and category slugs are also backtick-quoted kebab tokens.
