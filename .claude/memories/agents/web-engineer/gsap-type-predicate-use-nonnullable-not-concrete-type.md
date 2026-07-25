---
id: gsap-type-predicate-use-nonnullable-not-concrete-type
agent: [web-engineer]
trigger: [type predicate's type must be assignable to its parameter's type, narrowing HTMLXRef.current array, GSAP transform aliases]
rule: "Narrowing an array of ref values to one named DOM type fails `next build`'s type pass when the union includes a type not assignable from that name — use `el is NonNullable<typeof el>`."
evidence: [NA-16]
uses: 0
status: active
---
