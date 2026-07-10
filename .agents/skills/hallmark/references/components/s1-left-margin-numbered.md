### S1 · Left-margin numbered

A narrow left column holds `01 — LABEL.`; the wide right column holds the heading and content.
_Use when:_ the page is editorial / specimen.
_Don't confuse with:_ S5 Bottom-anchored (which puts the label _under_ the section).

```html
<header class="head-margin">
  <p class="num-label">01 — Foundations</p>
  <h2>…</h2>
</header>
```

```css
.head-margin {
  display: grid;
  grid-template-columns: 10rem 1fr;
  gap: var(--space-xl);
  align-items: baseline;
}
```
