import { ControlSection } from '../../components/home/control-section';
import { DayNightWorkflow } from '../../components/home/day-night-workflow';
import { Hero } from '../../components/home/hero';
import { HowItWorks } from '../../components/home/how-it-works';
import { PhraseMarquee } from '../../components/home/phrase-marquee';
import { ProblemSection } from '../../components/home/problem-section';
import { ProofBar } from '../../components/home/proof-bar';
import { TeamPreview } from '../../components/home/team-preview';
import { WhyDifferent } from '../../components/home/why-different';

export default function HomePage() {
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
    </>
  );
}
