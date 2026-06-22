# nightshift — Docs home UI kit

A high-fidelity recreation of the nightshift documentation home, three-column docs layout.

## Files
- `index.html` — page assembly (nav + 3-column shell). Open this.
- `layout.jsx` — `Sidebar` (grouped nav + ⌘K search), `Content` (prose, install,
  command-reference grid, project-context code sample), `OnThisPage` (right rail).

## Layout
`NavBar` (shared) → left **Sidebar** · center **Content** · right **OnThisPage**.

## Components used
`NavBar`, `CommandCard`, `CodeBlock`, `InstallSnippet`, `Badge`, `Table` — from
`window.NightshiftDesignSystem_983007`. Command reference and the `project-context.md`
sample are taken verbatim from the upstream docs.
