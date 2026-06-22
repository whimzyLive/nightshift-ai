Status / metadata pill, monospace by default to match the terminal texture. Use for agent states, ticket status, version tags, and labels.

```jsx
<Badge tone="success" dot>passing</Badge>
<Badge tone="accent">v0.4.0</Badge>
<Badge tone="warning" dot>pending review</Badge>
<Badge tone="info" solid>PR #142</Badge>
```

Tones map to the semantic palette: `neutral · accent · info · success · warning · danger`. Props: `dot` (status indicator), `solid` (filled), `mono` (default true), `size: sm | md`.
