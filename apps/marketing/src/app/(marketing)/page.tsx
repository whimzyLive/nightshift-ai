import { HeroClient } from '../../components/hero/hero-client';
import { HowItWorksSection } from '../../components/sections/how-it-works-section';
import { TeamSection } from '../../components/sections/team-section';
import { InstallSection } from '../../components/sections/install-section';
import { getHeroContent } from '../../lib/get-hero-content';
import styles from './page.module.css';
import sectionTokens from '../../components/sections/section-tokens.module.css';

// Hero content is CMS-editable and must reflect admin edits without a
// redeploy (NA-16 AC6). Render at request time instead of prerendering at
// build time — the latter would require a live, migrated Postgres schema
// during `next build`, which isn't available in every build environment.
export const dynamic = 'force-dynamic';

export default async function Page() {
  const hero = await getHeroContent();

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <span className={styles.logo}>NX</span>
        <nav className={styles.nav}>
          <a
            href="https://nx.dev/docs/getting-started/intro"
            target="_blank"
            rel="noreferrer"
          >
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
        <HeroClient
          headline={hero.headline}
          subhead={hero.subhead}
          ctaLabel={hero.ctaLabel}
          ctaHref={hero.ctaHref}
        />

        <div className={sectionTokens.tokens}>
          <HowItWorksSection />
          <TeamSection />
          <InstallSection />
        </div>
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
