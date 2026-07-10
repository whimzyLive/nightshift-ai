<!-- nx configuration start-->
<!-- Leave the start & end comments to automatically receive updates. -->

# General Guidelines for working with Nx

- For navigating/exploring the workspace, invoke the `nx-workspace` skill first - it has patterns for querying projects, targets, and dependencies
- When running tasks (for example build, lint, test, e2e, etc.), always prefer running the task through `nx` (i.e. `nx run`, `nx run-many`, `nx affected`) instead of using the underlying tooling directly
- Prefix nx commands with the workspace's package manager (e.g., `pnpm nx build`, `npm exec nx test`) - avoids using globally installed CLI
- You have access to the Nx MCP server and its tools, use them to help the user
- For Nx plugin best practices, check `node_modules/@nx/<plugin>/PLUGIN.md`. Not all plugins have this file - proceed without it if unavailable.
- NEVER guess CLI flags - always check nx_docs or `--help` first when unsure

## Scaffolding & Generators

- For scaffolding tasks (creating apps, libs, project structure, setup), ALWAYS invoke the `nx-generate` skill FIRST before exploring or calling MCP tools

## When to use nx_docs

- USE for: advanced config options, unfamiliar flags, migration guides, plugin configuration, edge cases
- DON'T USE for: basic generator syntax (`nx g @nx/react:app`), standard commands, things you already know
- The `nx-generate` skill handles generator discovery internally - don't call nx_docs just to look up generator syntax

<!-- nx configuration end-->

# UI Layer

- ALL UI components are `.tsx` (TypeScript + JSX) — never `.jsx`, `.js`, or class components
- Use Tailwind CSS (v4, CSS-first `@theme` config) for ALL styling across the UI layer (apps/marketing, packages/ui, and any future UI workspace) — utility classes in TSX, design tokens as CSS variables in `@theme`
- Do NOT create CSS Modules (`*.module.css`), SCSS files, or hand-rolled per-component stylesheets
- Exception: `apps/marketing/src/app/(payload)/custom.scss` is Payload's generated admin override — leave it alone
- Invoke the `tailwind-design-system` skill before setting up or extending Tailwind config or building shared components in packages/ui
