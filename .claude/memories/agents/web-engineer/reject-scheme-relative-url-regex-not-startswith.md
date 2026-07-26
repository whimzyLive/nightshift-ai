---
id: reject-scheme-relative-url-regex-not-startswith
agent: [web-engineer]
trigger: [Payload validate function rejects scheme-relative URLs, open-redirect via //evil.example]
rule: A Payload global `validate` function rejecting anything but a "relative in-app path only" URL needs the regex `/^\/(?!\/)/`, not `value.startsWith('/')`.
evidence: [NA-16]
uses: 0
status: active
---
