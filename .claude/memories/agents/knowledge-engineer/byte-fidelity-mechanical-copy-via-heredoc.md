---
id: byte-fidelity-mechanical-copy-via-heredoc
agent: [knowledge-engineer]
trigger: [large mechanical doc backfill, byte-reproducible copy, generator script for regen]
rule: For a large first-time mechanical page backfill, use heredoc-driven bash scripts to inject sanitized frontmatter while `awk`/`sed`-copying verbatim body content, and keep the generator scripts f.
evidence: [PR#155]
uses: 0
status: active
---

## Why

Hand-retyping body content via Read+Write for ~70 reference pages (~18k source lines) risks
transcription drift, which contradicts the "auto" tier's byte-reproducibility requirement. Keeping
the generator scripts in the session scratchpad makes a re-run trivially re-executable for the
idempotence check.
