---
id: extend-shared-component-variant-prop-pattern
agent: [web-engineer]
trigger: [extending CtaButton with new size/variant, splitting monolithic class string into records]
rule: 'To extend a shared `packages/ui` primitive with new size/variant props, split the class string into BASE/SIZE/VARIANT records and destructure the new props before spreading `...rest`.'
evidence: [NA-34, NA-35]
uses: 0
status: active
---
