import { ControlSection } from '../../components/home/control-section';
import { DayNightWorkflow } from '../../components/home/day-night-workflow';
import { FaqPreview } from '../../components/home/faq-preview';
import { FinalCta } from '../../components/home/final-cta';
import { Hero } from '../../components/home/hero';
import { HowItWorks } from '../../components/home/how-it-works';
import { PhraseMarquee } from '../../components/home/phrase-marquee';
import { ProblemSection } from '../../components/home/problem-section';
import { ProofBar } from '../../components/home/proof-bar';
import { TeamPreview } from '../../components/home/team-preview';
import { WhyDifferent } from '../../components/home/why-different';
import { getHomeFaqs } from '../../lib/faq';

// Payload's Local API call below (getHomeFaqs) would otherwise make this
// route attempt static prerendering at `next build` time, which requires a
// migrated Postgres schema to exist (NA-16 memory). force-dynamic also
// means the FAQ preview reflects CMS edits immediately, with no redeploy.
export const dynamic = 'force-dynamic';

// Async page — the single top-level boundary where the Payload fetch for
// the FAQ preview happens (see NA-16 memory: a second nested async Server
// Component breaks RTL's render()). Every section below FaqPreview stays a
// plain synchronous server/client component.
export default async function HomePage() {
  const faqs = await getHomeFaqs();

  return (
    <>
      <Hero />
      <PhraseMarquee />
      <ProofBar />
      <ProblemSection />
      <HowItWorks />
      <DayNightWorkflow />
      <TeamPreview />
      <WhyDifferent />
      <ControlSection />
      <FaqPreview faqs={faqs} />
      <FinalCta />
    </>
  );
}
