### C2 · Inline form-as-CTA

The CTA _is_ the form — a single email input with a "Submit →" beside it. No separate landing for sign-up.
_Use when:_ the action is collecting an email.
_Don't confuse with:_ C1 Outlined chip (which navigates, not submits).

```html
<form class="cta-form">
  <label for="email" class="visually-hidden">Email</label>
  <input id="email" type="email" placeholder="you@example.com" />
  <button type="submit">Send →</button>
</form>
```

```css
.cta-form {
  display: grid;
  grid-template-columns: 1fr auto;
  border-bottom: 1px solid var(--color-ink);
}
.cta-form input {
  background: none;
  border: 0;
  padding: 0.7rem 0;
  min-height: 44px;
}
```
