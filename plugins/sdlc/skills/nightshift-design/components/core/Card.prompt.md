Base surface container — night-600 fill, hairline border, deep soft shadow. The structural primitive most other blocks sit inside.

```jsx
<Card>…</Card>
<Card glow>Featured / hero card with accent ring</Card>
<Card interactive onClick={…}>Clickable card with hover lift</Card>
```

Props: `glow` (accent ring), `interactive` (hover elevation), `padding` (px, default 24), `as` (element tag). On dark backgrounds always keep the hairline border — shadow alone won't separate it from the page.
