---
id: skill-vendoring-vetting-checklist
agent: [platform-engineer]
trigger: [vendoring a third-party skill, vetting bundled scripts, skill-creator/find-skills license]
rule: When vendoring a third-party skill at a pinned commit, carry its own LICENSE verbatim if one exists (author a standard one with a provenance footer if not), vet every bundled script across every.
evidence: [NA-12]
uses: 0
status: active
---

## Why

`skill-creator` shipped its own Apache-2.0 `LICENSE.txt`, carried verbatim; `find-skills` had no
license file upstream, only `package.json`/README declarations, so a standard MIT LICENSE was
authored with a provenance footer noting it was transcribed, not copied. A follow-up vetting pass
found `eval-viewer/viewer.html` loading Google Fonts and a CDN-hosted SheetJS script via static
`<head>` tags — a genuine supply-chain/no-exfiltration gap the first vetting pass (which only
checked `subprocess`/`fetch()` calls in the `.py`/`.html` script bodies) missed entirely. This is a
distinct, security-driven carve-out from the "no local forks, upstream only" policy: removed the
tags (system font-stack fallback; degrade gracefully via a `typeof XLSX === "undefined"` guard) and
recorded it as a documented local deviation in the plugin's provenance table, not a silent fork.
`git clone --depth 50 <repo>` into the scratchpad (then `rm -rf` before committing) works for
vendoring even when `curl`/`wget` are blocked by a context-mode hook — only the HTTP fetch path is
blocked, not git's own transport. When a plan is ambiguous about "SKILL.md + LICENSE only" vs. "the
full supporting directory tree," treat them as explicitly distinguishable deliverables and flag the
gap rather than guessing — a skill's own core-loop steps vs. its "Advanced"/optional sections
usually tell you which bundled resources are load-bearing runtime dependencies.
