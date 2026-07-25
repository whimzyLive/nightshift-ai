---
id: isolate-fallback-data-from-payload-config-other-imports
agent: [web-engineer]
trigger: [TextEncoder is not defined in jsdom, fallback default data co-located with a GlobalConfig object]
rule: Don't co-locate small "fallback/default content" data next to a Payload `GlobalConfig`/`CollectionConfig` object if a plain server function needs to import just the data.
evidence: [NA-16]
uses: 0
status: active
---
