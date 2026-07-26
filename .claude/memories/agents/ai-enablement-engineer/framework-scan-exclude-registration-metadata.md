---
id: framework-scan-exclude-registration-metadata
agent: [ai-enablement-engineer]
trigger: [framework-agnostic content scan, banning react/vue/expo tokens, skills-map.yml false positive]
rule: A framework-agnostic content scan (banning tokens like `react|vue|expo|...`) must be scoped to skill CONTENT only (`SKILL.md` + `references/*`), explicitly excluding the sibling `skills-map.yml`.
evidence: [NA-15]
uses: 0
status: active
---
