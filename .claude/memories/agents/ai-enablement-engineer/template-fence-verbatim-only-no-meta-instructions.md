---
id: template-fence-verbatim-only-no-meta-instructions
agent: [ai-enablement-engineer]
trigger: [marketing-context-template.md Template fence, writer-facing meta-instructions inside a rendered fence, illustrative example leaking into fresh render]
rule: A `## Template` fence that gets rendered verbatim into a generated config file must contain ONLY pure renderable output.
evidence: [NA-4]
uses: 0
status: active
---

## Why

Meta-instructions inside the fence leak into every generated `marketing-context.md`. A "replace
every `<...>` token" placeholder gate can't catch concrete-looking illustrative values that aren't
`<...>`-shaped — moving them below the fence sidesteps the gate entirely. Also: meta-instructions to
the executor (e.g. "note X here") must never sit inside a print-verbatim blockquote meant for the
end user — pull them out as a plain instruction sentence before the print cue.
