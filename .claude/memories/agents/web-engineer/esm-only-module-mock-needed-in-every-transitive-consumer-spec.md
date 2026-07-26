---
id: esm-only-module-mock-needed-in-every-transitive-consumer-spec
agent: [web-engineer]
trigger: [payloadcms richtext-lexical plaintext ESM-only, jest.mock needed in transitively-importing specs]
rule: "An ESM-only third-party module needs `jest.mock(...)` in EVERY spec that imports it transitively, not just the new module's own spec."
evidence: [NA-39]
uses: 0
status: active
---
