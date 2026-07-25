---
id: string-template-generator-edit-needs-py-compile-check
agent: [platform-engineer]
trigger: [editing a python HTML report generator, triple-quoted template string, stray content at end of a plan doc]
rule: A Python generator embedding its whole template as one triple-quoted string is safe to edit for text-only swaps (font-family values, stripping a tag), but always re-run `python3 -m py_compile` a.
evidence: [NA-12]
uses: 0
status: active
---

## Why

Also worth checking: stray `</content>`/`</invoke>` tool-call artifact tags at the tail of a
generated plan doc are only visible via `tail -5`, not a normal Read — check the very end of any
doc a review flags as having "stray content at end of file."
