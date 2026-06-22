# nightshift — Marketing site UI kit

A high-fidelity recreation of the nightshift landing page, composed entirely from
the design-system primitives.

## Files
- `index.html` — the full landing page (mount + page assembly). Open this.
- `sections.jsx` — section components: `Hero`, `Problem`, `HowItWorks`, `Team`, `Install`,
  plus an `AnimatedTerminal` that streams a live `/auto PROJ-142` pipeline run.

## Sections (top → bottom)
1. **NavBar** — sticky, translucent night blur, logo lockup, GitHub stars, Install CTA.
2. **Hero** — tagline, sub-hook, the `Jira → … → PR` mono pipeline line, dual CTA + `InstallSnippet`,
   and the animated terminal demo on the right.
3. **Problem** — "connective tissue" thesis, centered.
4. **How it works** — the three ideas as cards + a `Pipeline` flow diagram.
5. **Meet your team** — the 11 agents in an `AgentCard` grid (standby roles dimmed).
6. **Install** — the two-line install in 60 seconds.
7. **Footer** — brand + column nav on `night-void`.

## Components used
`NavBar`, `Footer`, `Hero` blocks, `Terminal`, `Pipeline`, `AgentCard`, `InstallSnippet`,
`Button`, `Badge` — all from `window.NightshiftDesignSystem_983007`.

Copy verbatim from the upstream README to keep the technical, no-hype voice.
