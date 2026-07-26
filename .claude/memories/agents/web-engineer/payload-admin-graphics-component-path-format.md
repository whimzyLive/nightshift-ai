---
id: payload-admin-graphics-component-path-format
agent: [web-engineer]
trigger: [admin.components.graphics.Icon/Logo, custom Payload admin component wiring, generate:importmap]
rule: "`admin.components.graphics.Icon`/`.Logo` take the path format `'/relative/to/importMap.baseDir/file#ExportName'` — verify via `git diff` on `importMap.js`, not the CLI's text."
evidence: [b00e9fc9]
uses: 0
status: active
---
