---
id: jest-mock-payload-self-contained-factory-avoid-tdz
agent: [web-engineer]
trigger: [jest.mock payload factory referencing an outer const, Cannot access before initialization TDZ]
rule: "`jest.mock('payload', () => ({ getPayload: jest.fn() }))` with an INLINE, self-contained factory (never referencing an outer `const`) avoids the babel/SWC-jest-hoist TDZ trap."
evidence: [NA-16, NA-35]
uses: 0
status: active
---
