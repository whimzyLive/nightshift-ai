---
id: mock-must-mirror-real-library-semantics-not-fabricated-behavior
agent: [web-engineer]
trigger: [gsap matchMedia mock captures handler and invokes manually, testing the mock's own behavior not the real contract]
rule: A jest mock that just captures a library's registration handler and invokes it manually with a hand-picked argument object tests the mock's own fabricated behavior, not the library's real contra.
evidence: [NA-16]
uses: 0
status: active
---
