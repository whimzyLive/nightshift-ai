import { getHomeContent, getSiteSettings } from '../../lib/content';
import { Hero } from './_components/Hero';
import { ProofBar } from './_components/ProofBar';
import { Problem } from './_components/Problem';
import { HowItWorks } from './_components/HowItWorks';
import { Workflow } from './_components/Workflow';
import { Team } from './_components/Team';
import { WhyDifferent } from './_components/WhyDifferent';
import { Control } from './_components/Control';
import { Faq } from './_components/Faq';
import { FinalCta } from './_components/FinalCta';

export const revalidate = 60;

export default async function HomePage() {
  const [home, siteSettings] = await Promise.all([
    getHomeContent(),
    getSiteSettings(),
  ]);
  return (
    <main>
      <Hero content={home?.hero} siteSettings={siteSettings} />
      <ProofBar content={home?.proofBar} />
      <Problem content={home?.problem} />
      <HowItWorks content={home?.howItWorks} />
      <Workflow content={home?.workflow} />
      <Team content={home?.team} />
      <WhyDifferent content={home?.whyDifferent} />
      <Control content={home?.control} />
      <Faq content={home?.faq} />
      <FinalCta
        content={home?.finalCta}
        siteSettings={siteSettings}
        starCtaLabel={home?.hero?.starCtaLabel}
      />
    </main>
  );
}
