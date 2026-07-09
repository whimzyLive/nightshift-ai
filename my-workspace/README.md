# Nx Next.js Template

<a alt="Nx logo" href="https://nx.dev" target="_blank" rel="noreferrer"><img src="https://raw.githubusercontent.com/nrwl/nx/master/images/nx-logo.png" width="45"></a>

A production-ready monorepo starter for teams who want App Router, shared UI libraries, and Nx superpowers without the setup tax.
## Finish your Nx platform setup

🚀 [Finish setting up your workspace](https://cloud.nx.app/connect/Ez9sFGKp15) to get faster builds with remote caching, distributed task execution, and self-healing CI. [Learn more about Nx Cloud](https://nx.dev/ci/intro/why-nx-cloud).

## Quick Start

### Create a new workspace from this template

```sh
npx create-nx-workspace@latest my-workspace --template nrwl/nextjs-template
```

### Or clone and run locally

```sh
git clone https://github.com/nrwl/nextjs-template.git my-workspace
cd my-workspace
npm install
```

### Common commands

| Task | Command |
|------|---------|
| Start dev server | `npx nx run @nextjs-template/web:dev` |
| Build all projects | `npx nx run-many -t build` |
| Run all tests | `npx nx run-many -t test` |
| Run affected tests | `npx nx affected -t test` |
| Lint affected | `npx nx affected -t lint` |
| View project graph | `npx nx graph` |
| E2E tests | `npx nx run @nextjs-template/web-e2e:e2e` |

---

## What's inside

```
nextjs-template/
- apps/
  - web/          Next.js 16 App Router application (scope:web)
  - web-e2e/      Playwright end-to-end tests
- packages/
  - ui/           Shared React component library (scope:shared)
                  -> HeroBanner, FeatureCard (used by web home page)
```

### Key choices

- **Next.js 16 App Router** with `src/` directory layout
- **TypeScript** throughout - strict mode enabled
- **Jest** for unit tests, **Playwright** for e2e
- **ESLint** with module boundary enforcement (tags: `scope:web`, `scope:shared`)
- **npm** as package manager

---

## Featured Nx capabilities

### Computation caching

Every task result is cached locally. Running `npx nx run @nextjs-template/web:build` a second time takes milliseconds.

```sh
npx nx run @nextjs-template/web:build        # first run: compiles
npx nx run @nextjs-template/web:build        # second run: instant (cache hit)
```

### Affected commands

Only run work that is actually impacted by your changes:

```sh
npx nx affected -t build,test,lint
```

### Module boundaries

Tags on each project enforce architectural rules via ESLint:

- `scope:web` projects can import from `scope:shared`
- `scope:shared` projects cannot import from `scope:web`

Add rules in `eslint.config.mjs` under `@nx/enforce-module-boundaries`.

### Project graph

Visualize the dependency graph of your entire workspace:

```sh
npx nx graph
```

### Code generation

Scaffold new apps, libraries, and components with generators:

```sh
# Add another Next.js app
npx nx g @nx/next:app apps/dashboard

# Add a new shared library
npx nx g @nx/react:lib packages/utils --bundler=none

# Add a component to the UI lib
npx nx g @nx/react:component packages/ui/src/lib/button
```

---

## Nx Cloud

Nx Cloud extends local caching to your entire team and CI pipeline.

- **Remote cache** - A build on any machine is available to every other machine instantly.
- **Distributed task execution (DTE)** - Tasks run in parallel across many CI agents - no changes to your yaml required.
- **Flaky task detection** - Nx Cloud tracks flaky tests and re-runs them automatically.
- **Nx Agents** - Ephemeral CI agents that scale with your task graph.

Learn more: https://nx.dev/nx-cloud

Connect: https://cloud.nx.app/get-started

---

## Install Nx Console

Nx Console is an editor extension that enriches your developer experience. It lets you run tasks, generate code, and improves code autocompletion in your IDE. It is available for VSCode and IntelliJ.

[Install Nx Console &raquo;](https://nx.dev/docs/getting-started/editor-setup?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

## 🔗 Learn More

- [Nx Documentation](https://nx.dev/docs)
- [Crafting Your Workspace Tutorial](https://nx.dev/docs/getting-started/tutorials/crafting-your-workspace)
- [Module Boundaries](https://nx.dev/docs/features/enforce-module-boundaries)
- [Next.js Documentation](https://nextjs.org/docs)
- [Playwright Testing](https://nx.dev/docs/technologies/test-tools/playwright)
- [Nx Cloud](https://nx.dev/nx-cloud)

## 💬 Community

Join the Nx community:

- [Discord](https://go.nx.dev/community)
- [X (Twitter)](https://twitter.com/nxdevtools)
- [LinkedIn](https://www.linkedin.com/company/nrwl)
- [YouTube](https://www.youtube.com/@nxdevtools)
- [Blog](https://nx.dev/blog)
