---
id: mixed-field-array-typing-degrades-validate-callback-inference
agent: [web-engineer]
trigger: [Payload fields array, one broadly-typed Field element degrades sibling literal typing, implicit any on validate value]
rule: Mixing one array element typed as the broad `Field` union with other elements left as inline object literals in the same Payload `fields: [...]` array degrades TypeScript's contextual typing for.
evidence: [NA-31]
uses: 0
status: active
---
