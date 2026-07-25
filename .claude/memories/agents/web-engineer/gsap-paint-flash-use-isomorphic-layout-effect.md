---
id: gsap-paint-flash-use-isomorphic-layout-effect
agent: [web-engineer]
trigger: [GSAP entrance tween flashes end-state before applying start state, useLayoutEffect SSR warning]
rule: GSAP entrance tweens set up in a plain `useEffect` run after first paint, so the browser can flash the tween's end state (from CSS/inline styles) before GSAP applies the `.from(...)` start state.
evidence: [NA-16]
uses: 0
status: active
---
