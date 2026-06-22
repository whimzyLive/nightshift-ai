Primary action button — terracotta-accented, dark-mode native. Use for any click action; reach for `mono` when the label is a command.

```jsx
<Button variant="primary" size="md">Install plugin</Button>
<Button variant="secondary" iconLeft={<GitHubIcon/>}>Star on GitHub</Button>
<Button variant="ghost" mono>/auto</Button>
<Button variant="primary" loading>Running…</Button>
```

Variants: `primary` (filled terracotta + glow), `secondary` (raised surface + hairline), `ghost` (text-only, fills on hover), `danger` (red outline). Sizes `sm | md | lg`. Props: `mono`, `loading`, `disabled`, `iconLeft/iconRight`, `fullWidth`.
