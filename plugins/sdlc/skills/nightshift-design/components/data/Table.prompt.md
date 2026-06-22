Data table for the night palette — uppercase mono headers, hairline row dividers, hover highlight. Cells accept strings or React nodes (drop a `<Badge>` in).

```jsx
<Table
  columns={[
    { key: 'agent', header: 'Agent', mono: true },
    { key: 'owns', header: 'Owns' },
    { key: 'status', header: 'Status', align: 'right' },
  ]}
  rows={[
    { agent: 'product-manager', owns: 'Vague idea → PRD', status: <Badge tone="success" dot>done</Badge> },
  ]} />
```

Column flags: `mono`, `muted`, `align`. `dense` tightens padding.
