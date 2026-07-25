---
id: jest-setup-dom-already-polyfills-browser-apis-check-first
agent: [web-engineer]
trigger: [jest.setup.dom.js, matchMedia already polyfilled globally, avoid redundant per-test mocks]
rule: '`jest.setup.dom.js` (repo root) already polyfills `matchMedia` (defaults `matches:false` unless a test overrides it), `IntersectionObserver`, `ResizeObserver`, and `scrollTo` globally for every.'
evidence: [e165158]
uses: 0
status: active
---
