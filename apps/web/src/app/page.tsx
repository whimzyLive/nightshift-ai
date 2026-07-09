import { HeroBanner, FeatureCard } from '@nextjs-template/ui';
import styles from './page.module.css';

const features = [
  {
    icon: '⚡',
    title: 'Computation Caching',
    description:
      'Nx caches the output of every task. Re-running a cached task takes milliseconds, not minutes.',
    href: 'https://nx.dev/docs/features/cache-task-results',
  },
  {
    icon: '🎯',
    title: 'Affected Commands',
    description:
      'Run only the tasks that are affected by your latest changes. Skip everything else.',
    href: 'https://nx.dev/docs/features/ci-features/affected',
  },
  {
    icon: '🏗️',
    title: 'Module Boundaries',
    description:
      'Enforce architectural rules with ESLint. Keep your codebase modular as it grows.',
    href: 'https://nx.dev/docs/features/enforce-module-boundaries',
  },
  {
    icon: '☁️',
    title: 'Nx Cloud',
    description:
      'Remote caching, distributed task execution, and self-healing CI - all in one platform.',
    href: 'https://cloud.nx.app/get-started',
  },
  {
    icon: '📦',
    title: 'Shared UI Library',
    description:
      'This page itself imports components from packages/ui - a shared React library wired into the workspace.',
  },
  {
    icon: '🔍',
    title: 'Project Graph',
    description:
      'Visualize your workspace dependencies with a single command: npx nx graph.',
    href: 'https://nx.dev/docs/features/explore-graph',
  },
];

export default function Page() {
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <span className={styles.logo}>NX</span>
        <nav className={styles.nav}>
          <a href="https://nx.dev/docs/getting-started/intro" target="_blank" rel="noreferrer">
            Docs
          </a>
          <a href="https://nx.dev/blog" target="_blank" rel="noreferrer">
            Blog
          </a>
          <a
            href="https://cloud.nx.app/get-started"
            target="_blank"
            rel="noreferrer"
            className={styles.cloudLink}
          >
            Connect to Nx Cloud
          </a>
        </nav>
      </header>

      <main className={styles.main}>
        <HeroBanner
          title="Nx + Next.js Starter"
          subtitle="A production-ready monorepo template with App Router, shared UI libraries, and Nx superpowers built in."
          ctaHref="https://cloud.nx.app/get-started"
          ctaLabel="Enable Nx Cloud - Free Remote Cache"
        />

        <section className={styles.cloudCallout}>
          <div className={styles.cloudCalloutInner}>
            <span className={styles.cloudIcon}>☁️</span>
            <div>
              <strong>Speed up CI with Nx Cloud</strong>
              <p>
                Remote caching, distributed task execution (DTE), and self-healing CI.{' '}
                <a
                  href="https://cloud.nx.app/get-started"
                  target="_blank"
                  rel="noreferrer"
                >
                  Connect your workspace - it&apos;s free to start.
                </a>
              </p>
            </div>
          </div>
        </section>

        <section className={styles.featuresSection}>
          <h2 className={styles.sectionTitle}>What&apos;s included</h2>
          <div className={styles.featuresGrid}>
            {features.map((f) => (
              <FeatureCard key={f.title} {...f} />
            ))}
          </div>
        </section>

        <section className={styles.commandsSection}>
          <h2 className={styles.sectionTitle}>Quick commands</h2>
          <div className={styles.commandsGrid}>
            <div className={styles.commandBlock}>
              <h3>Develop</h3>
              <pre><code>npx nx serve web</code></pre>
            </div>
            <div className={styles.commandBlock}>
              <h3>Build all</h3>
              <pre><code>npx nx run-many -t build</code></pre>
            </div>
            <div className={styles.commandBlock}>
              <h3>Test affected</h3>
              <pre><code>npx nx affected -t test</code></pre>
            </div>
            <div className={styles.commandBlock}>
              <h3>Visualize graph</h3>
              <pre><code>npx nx graph</code></pre>
            </div>
          </div>
        </section>
      </main>

      <footer className={styles.footer}>
        <p>
          Built with{' '}
          <a href="https://nx.dev" target="_blank" rel="noreferrer">
            Nx
          </a>{' '}
          and{' '}
          <a href="https://nextjs.org" target="_blank" rel="noreferrer">
            Next.js
          </a>
        </p>
      </footer>
    </div>
  );
}
