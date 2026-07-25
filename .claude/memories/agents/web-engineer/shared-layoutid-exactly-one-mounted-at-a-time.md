---
id: shared-layoutid-exactly-one-mounted-at-a-time
agent: [web-engineer]
trigger: [duplicate layoutId flicker, Framer shared-layout morph, two elements same layoutId simultaneously mounted]
rule: Two elements sharing the exact same Motion `layoutId` SIMULTANEOUSLY MOUNTED (not sequentially swapped) is the actual anti-pattern behind a "duplicate layoutId" report.
evidence: [NA-69]
uses: 0
status: active
---
