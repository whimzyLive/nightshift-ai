---
name: nightshift-design
description: Use this skill to generate well-branded interfaces and assets for nightshift, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.
If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand.
If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

## Quick reference

**Brand:** nightshift — a Claude Code plugin that turns one terminal into a full AI software-delivery team. Tagline: "Your AI software team that ships while you sleep." Nocturnal, calm, technical, no-hype. The name is always lowercase.

**Tokens** (`styles.css` → `tokens/`): dark-mode-first night-sky base (`--bg-page` #0d0d18, `--surface-card` #1a1a2e), terracotta accent (`--accent` #d97757), moonlight text (`--text-strong` #f5f3ef), moonlit-indigo links (`--link` #7c93f0). Inter for display/body, JetBrains Mono for code/labels/eyebrows.

**Components** (`window.NightshiftDesignSystem_983007`): Button, Badge, Card, InstallSnippet, Terminal, CodeBlock, Pipeline, NavBar, Footer, AgentCard, CommandCard, Table.

**Signature moves:** mono `// uppercase eyebrows`, the terminal window surface with streaming `/auto` pipeline output, faint starfield + soft moon-glow behind heroes, glow on primary buttons & active pipeline stages, hairline borders on every card.

**Voice:** technical peer not marketer; "you" for the reader; numbers as proof; thesis → mechanism → proof; mono for anything you'd type. Never Title-Case the brand, never over-claim.

See README.md for the full content + visual foundations, iconography, and the file index.
