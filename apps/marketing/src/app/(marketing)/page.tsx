import type { Metadata } from 'next';

import { Faq } from '../../components/sections/faq';
import { FinalCta } from '../../components/sections/final-cta';
import { Hero } from '../../components/sections/hero';
import { HowItWorks } from '../../components/sections/how-it-works';
import { Problem } from '../../components/sections/problem';
import { ProofBar } from '../../components/sections/proof-bar';
import { Team } from '../../components/sections/team';
import { WhyDifferent } from '../../components/sections/why-different';
import { SiteFooter } from '../../components/site-footer';
import { SiteNav } from '../../components/site-nav';
import { CANONICAL_URL, JSON_LD } from '../../content/site';

export const metadata: Metadata = {
  title: 'nightshift — your AI software team that ships while you sleep',
  description:
    'nightshift is a free, MIT-licensed Claude Code plugin that runs your whole SDLC. It reads a Jira ticket and ships the spec, plan, code, and review automatically.',
  alternates: {
    canonical: CANONICAL_URL,
  },
  icons: {
    icon: '/brand/favicon.svg',
  },
  openGraph: {
    type: 'website',
    siteName: 'nightshift',
    title: 'Your AI software team that ships while you sleep',
    description:
      'A Claude Code plugin that turns one terminal into a full delivery team — PM, architect, tech lead, engineers, QA. Ticket in, reviewed PR out. Free and MIT.',
    url: CANONICAL_URL,
    images: [
      {
        url: `${CANONICAL_URL}/og-image.png`,
        alt: 'nightshift pipeline: Jira ticket to spec to plan to implementation to review to PR',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Your AI software team that ships while you sleep',
    description:
      'A Claude Code plugin that runs your whole SDLC — spec, plan, code, review — from one ticket. Free and MIT.',
    images: [`${CANONICAL_URL}/og-image.png`],
  },
};

export default function Page() {
  return (
    <>
      {/* JSON-LD embedded verbatim from docs/gtm/site-brief.md §3. */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(JSON_LD) }}
      />
      <SiteNav />
      <main>
        <Hero />
        <ProofBar />
        <Problem />
        <HowItWorks />
        <Team />
        <WhyDifferent />
        <Faq />
        <FinalCta />
      </main>
      <SiteFooter />
    </>
  );
}
