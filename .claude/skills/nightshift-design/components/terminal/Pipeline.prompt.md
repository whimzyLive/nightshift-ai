The lifecycle as connected blocks — spec → plan → impl → review → PR. Each stage carries a command, label, owning agent, and status; connectors turn green as stages complete.

```jsx
<Pipeline stages={[
  { command: '/spec', label: 'Technical spec', agent: 'solutions-architect', status: 'done' },
  { command: '/plan', label: 'Ordered plan', agent: 'tech-lead', status: 'active' },
  { command: '/impl', label: 'Implementation', agent: 'principal-engineer' },
  { command: '/review', label: 'Quality gate', agent: 'qa-engineer' },
]} />
```

Status: `idle | active | done` (active gets the accent glow, done a green check). `orientation: horizontal | vertical`.
