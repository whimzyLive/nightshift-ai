### H6 · Photographic Fold

Single full-bleed image fills the viewport. Caption sits in a corner.
_Use when:_ you have real photography that earns full-bleed.
_Don't confuse with:_ H2 Split (which pairs image with text in a grid).

```html
<section class="hero-photo">
  <img class="bleed" src="" alt="" />
  <p class="caption">Spring, 2026.</p>
</section>
```

```css
.hero-photo {
  position: relative;
  height: 80dvh;
}
.hero-photo .bleed {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.hero-photo .caption {
  position: absolute;
  bottom: var(--space-md);
  right: var(--space-md);
}
```
