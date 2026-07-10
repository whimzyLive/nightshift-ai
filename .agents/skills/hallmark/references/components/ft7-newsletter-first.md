### Ft7 · Newsletter-first

The form (label + input + submit) is the _primary_ element of the footer; everything else (wordmark, links, copyright) is set in 12 px muted type beneath. Stratechery, Substack-shaped sites, indie magazines.
_Use when:_ the brand legitimately publishes — and the page above the fold has _already_ offered a subscription. The footer is a final invitation, not an ambush.
_Don't confuse with:_ Ft1 (which doesn't ask for anything).

```html
<footer class="foot-news">
  <form class="foot-news__form" action="/subscribe" method="post">
    <label for="foot-email">Letters from the studio · monthly</label>
    <div class="foot-news__row">
      <input id="foot-email" name="email" type="email" required placeholder="you@domain" />
      <button type="submit" class="cta-fill">Subscribe</button>
    </div>
  </form>
  <p class="foot-news__meta muted">Studio · © 2026 · <a href="/imprint">Imprint</a></p>
</footer>
```

```css
.foot-news {
  padding: var(--space-2xl) var(--page-gutter);
  display: grid;
  gap: var(--space-lg);
  max-width: 56ch;
}
.foot-news__form label {
  display: block;
  font-size: var(--text-sm);
  margin-block-end: var(--space-2xs);
}
.foot-news__row {
  display: flex;
  gap: var(--space-2xs);
}
.foot-news__row input {
  flex: 1;
  min-height: 44px;
  padding-inline: var(--space-sm);
  border: var(--rule-hair) solid var(--color-rule);
  border-radius: var(--radius-input);
  background: var(--color-paper);
}
.foot-news__row input:focus-visible {
  outline: 2px solid var(--color-focus);
  outline-offset: 1px;
}
.foot-news__meta {
  font-size: var(--text-xs);
}
```

_Anti-pattern:_ Ft7 when the page never said "subscribe" above the fold. The footer is an honest _conclusion_; if you didn't ask, don't ambush. Drop to Ft2 instead.
