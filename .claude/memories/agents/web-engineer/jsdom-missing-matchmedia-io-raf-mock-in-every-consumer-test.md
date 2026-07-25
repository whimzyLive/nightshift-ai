---
id: jsdom-missing-matchmedia-io-raf-mock-in-every-consumer-test
agent: [web-engineer]
trigger: [window.matchMedia not a function, IntersectionObserver undefined, page-level test rendering component indirectly]
rule: jsdom implements neither `window.matchMedia`, `window.IntersectionObserver`, nor `window.requestAnimationFrame` by default.
evidence: [NA-32]
uses: 0
status: active
---

## Why

Because `IntersectionObserver` is unsupported by default, a "reveal on first viewport entry,
unsupported → render final value" component's degrade path fires automatically in every test that
doesn't install a fake `window.IntersectionObserver` — useful for the "renders final value" branch,
but the "renders 0 initially" branch needs its own test installing a no-op fake class (`observe`/
`disconnect` as `jest.fn()`, never invoking the stored callback). `getByText` also fails for text
split across a primitive boundary (e.g. `<CountUp>11</CountUp> agents`) — check
`container.textContent` (which recurses) instead (see `rtl-getbytext-only-matches-direct-text-node-children`).
