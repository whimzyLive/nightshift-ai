### H1 · Marquee

A single statement fills the fold. No subhead, no CTA in view.
_Use when:_ the brand or person _is_ the message.
_Don't confuse with:_ H4 Stat-Led (which is a number, not a statement).

```html
<section class="hero-marquee">
  <h1 class="display-xxl">A statement.</h1>
</section>
```

```css
.hero-marquee {
  min-height: 80dvh;
  display: grid;
  align-content: end;
  padding: 0 var(--page-gutter) var(--space-2xl);
}
.display-xxl {
  font-size: clamp(4rem, 12vw, 12rem);
  line-height: 0.92;
}
```
