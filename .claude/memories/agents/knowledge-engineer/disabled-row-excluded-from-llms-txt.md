---
id: disabled-row-excluded-from-llms-txt
agent: [knowledge-engineer]
trigger: [llms.txt regen, manifest row enabled false, docs audit]
rule: When a manifest row is `enabled: false`, drop its page from `llms.txt` even if the file still exists on disk — exclusion is keyed on manifest state, not file existence.
evidence: [PR#155]
uses: 0
status: active
---

## Why

The `changelog` row was flipped to `enabled: false` in a prior commit that kept
`docs/changelog/index.md` on disk as a hand-maintained pointer page. The generation algorithm's own
rule ("generated pages of every ENABLED public:yes row") means that page must drop out of `llms.txt`
regardless of whether the file itself is still linked from elsewhere. Caught by diffing the
manifest's `enabled` column against what the existing `llms.txt` still listed.
