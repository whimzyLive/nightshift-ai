Slash-command reference entry for the docs — command, argument signature, description, and the agents it dispatches.

```jsx
<CommandCard command="/auto" args="<TICKET>"
  description="The whole pipeline, end to end — ticket in, reviewed PR out."
  agents={['product-manager','solutions-architect','tech-lead','qa-engineer']} />
<CommandCard command="/spec"
  description="Produce the technical design spec for a story."
  agents={['solutions-architect']} output="docs/superpowers/specs/PROJ-142.md" />
```

Props: `command`, `args`, `description`, `agents[]`, `output`. Accent border on hover.
