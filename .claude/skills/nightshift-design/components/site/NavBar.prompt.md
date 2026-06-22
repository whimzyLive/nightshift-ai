Sticky marketing/docs top nav — logo lockup, link list, GitHub stars pill, primary CTA. Translucent night backdrop with blur.

```jsx
<NavBar
  links={[{label:'How it works'},{label:'The team'},{label:'Docs'},{label:'Pricing'}]}
  active="Docs" stars="1.2k" ctaLabel="Install" />
```

Props: `links` (`{label, href}[]`), `active`, `stars`, `ctaLabel`/`onCta`, `logoSrc`. Set `logoSrc` to the correct relative path to `assets/logomark.svg` from your page.
