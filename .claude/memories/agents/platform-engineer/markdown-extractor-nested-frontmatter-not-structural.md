---
id: markdown-extractor-nested-frontmatter-not-structural
agent: [platform-engineer]
trigger: [markdown content-contract extraction, nested frontmatter inside a fence, yaml field scope in a template, extending artifact-contract.sh]
rule: When extracting yaml fields from markdown, only a document-leading `---` block or a ```yaml fence counts — a `---` block nested inside another fence is decorative, not structural.
evidence: [NA-87]
uses: 0
status: active
---
