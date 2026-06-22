Site footer — brand lockup + tagline on the left, structured column nav on the right, fine print row beneath.

```jsx
<Footer columns={[
  { title: 'Product', items: ['How it works', 'The team', 'Commands'] },
  { title: 'Docs', items: ['Quickstart', 'Configure', 'Extend'] },
  { title: 'Community', items: ['GitHub', 'Discord', 'Changelog'] },
]} />
```

Props: `columns` (`{title, items[]}[]`), `tagline`, `bottomNote`, `builtOn`, `logoSrc`. Sits on the deepest `night-void` so it reads as the page floor.
