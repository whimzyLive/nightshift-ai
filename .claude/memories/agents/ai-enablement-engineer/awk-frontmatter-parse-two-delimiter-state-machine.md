---
id: awk-frontmatter-parse-two-delimiter-state-machine
agent: [ai-enablement-engineer]
trigger: [frontmatter-only parse guard, ignore skills: mentions in body, sed range misfiring on body ---]
rule: 'For a frontmatter-only parse guard, use a tiny awk state machine anchored on `NR==1` for the opening `---`, not a `sed` range, which misfires if the body later reintroduces a bare `---`.'
evidence: [NA-25]
uses: 0
status: active
---

## Why

Without the `NR==1` anchor on the opener, a frontmatter-less file whose body happens to contain two
`---` lines with something matching `^skills:` between them false-positives, since the awk state
machine treats the FIRST `---` it sees anywhere in the file as the opener. Verify the anchored
version against a crafted scratch file (no real frontmatter, plain body containing a `---`/matching
line/`---` span) that the unanchored version would have flagged.
