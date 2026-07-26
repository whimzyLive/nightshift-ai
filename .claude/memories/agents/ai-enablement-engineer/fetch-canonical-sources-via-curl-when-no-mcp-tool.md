---
id: fetch-canonical-sources-via-curl-when-no-mcp-tool
agent: [ai-enablement-engineer]
trigger: [fetching canonical doc pages, context-mode MCP tools not actually callable, curl -sL plus python strip]
rule: When a dispatch's tool list only actually exposes Read/Write/Edit/Bash/Skill (no context-mode MCP fetch/index tools callable despite a context-mode banner in the prompt), use `curl -sL` plus a s.
evidence: [NA-44, NA-58]
uses: 0
status: active
---
