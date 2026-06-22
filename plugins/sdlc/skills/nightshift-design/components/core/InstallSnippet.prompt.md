Copy-to-clipboard command line — the signature "install in 60 seconds" affordance. Terminal-well styling, accent border on hover, inline copy confirmation.

```jsx
<InstallSnippet label="Install in 60 seconds" />
<InstallSnippet command="/plugin marketplace add whimzyLive/nightshift-ai" prompt="$" />
```

Props: `command`, `prompt` (default `$`), `label` (optional uppercase mono caption). The copy button flips to `copied ✓` in green for ~1.6s.
