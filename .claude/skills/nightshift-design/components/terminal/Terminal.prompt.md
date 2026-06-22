Terminal window frame — macOS traffic lights, centered title, dark output body. The brand's hero surface; use it to show real `/auto` pipeline output.

```jsx
<Terminal title="zsh — acme-api" lines={[
  { prompt: '$', text: '/auto PROJ-142' },
  { agent: 'product-manager', text: '→ reads the ticket, writes a PRD', tone: 'accent' },
  { agent: 'qa-engineer', text: '→ quality gate passed', tone: 'success' },
]} />
```

Each line: `{ text, tone, prompt, agent, indent, dim }`. Tones: `default · success · warning · danger · info · muted · accent`. Pass `children` instead of `lines` for custom content. Also exports `TermLine`.
