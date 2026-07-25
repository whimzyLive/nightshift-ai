---
id: extract-html-from-js-bundled-string-export
agent: [web-engineer]
trigger: [standalone HTML design export is actually a JS-bundler artifact, escaped HTML inside a giant string literal]
rule: A user-attached "standalone" HTML design export can look like plain static markup but actually be a JS-bundler artifact with the real HTML escaped inside a giant JS string literal.
evidence: [PR#97]
uses: 0
status: active
---

## Why

Confirmed real page coverage via the extracted HTML's own `id="..."` markers before assuming the
export covers "all pages" as requested — it may only cover a subset (e.g. home/landing only).
