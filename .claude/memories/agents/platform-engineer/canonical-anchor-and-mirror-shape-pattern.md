---
id: canonical-anchor-and-mirror-shape-pattern
agent: [platform-engineer]
trigger: [linking to a shared ref anchor, mirroring a shipped agent's shape, opt-in agent Active definition, self-contained override in init.md]
rule: When writing a new agent/command that references a shared ref doc's heading, derive the GitHub-style anchor slug mechanically (lowercase, strip punctuation, spaces to hyphens) and cross-check it.
evidence: [NA-12]
uses: 0
status: active
---

## Why

"Mark the agent Active" needs no new boolean field — this repo's model treats presence of a
workspace→agent row as the sole activity signal; reuse that exact mechanism for a new opt-in agent
rather than inventing a parallel activation concept (keeps the "single fact" ownership model
literally true). For a new domain agent that isn't a normal multi-select at init (gated by its own
single opt-in instead), give it a self-contained, fixed override body inline in `init.md` itself,
explicitly bypassing the stack-driven agent-domain-mapping tables the shared templates define for
other agents — this keeps the phase's diff scoped to one file while still producing a fully
no-placeholder override on scaffold. Verify "no hard-coded area path" in write-scope resolution
logic by grepping the finished file for the literal area string and confirming every hit is either
frontmatter prose or an illustrative "e.g." — never inside the actual resolution logic. A newly
opted-in agent's workspace→agent row write needs a "does the target directory exist" precondition,
matching the pre-existing drift check that flags a table row pointing at a path that doesn't exist.
