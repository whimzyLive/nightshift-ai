### H4 · Stat-Led

A giant number or metric is the hero. A small qualifier line below.
_Use when:_ you have one defensible, externally-verifiable number.
_Don't confuse with:_ T4 Numbered stat strip (which is several stats in a row, not one focal).

```html
<section class="hero-stat">
  <p class="figure tnum">99.97<span class="unit">%</span></p>
  <p class="qualifier">…</p>
</section>
```

```css
.figure {
  font-size: clamp(6rem, 18vw, 16rem);
  font-variant-numeric: tabular-nums;
  line-height: 0.85;
}
```
