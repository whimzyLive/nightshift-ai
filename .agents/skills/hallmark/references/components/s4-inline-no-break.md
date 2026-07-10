### S4 · Inline (no break)

The heading is a small caps phrase that emerges _inside_ the body flow; no spatial break.
_Use when:_ the page is prose-led; reading should be continuous.
_Don't confuse with:_ S2 Hanging (which separates with negative space).

```html
<p>… <span class="head-inline">A small heading.</span> …</p>
```

```css
.head-inline {
  font-variant-caps: all-small-caps;
  letter-spacing: 0.06em;
  font-weight: 500;
}
```
