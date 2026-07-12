import { Hero } from '../../components/home/hero';
import { PhraseMarquee } from '../../components/home/phrase-marquee';
import { ProblemSection } from '../../components/home/problem-section';
import { ProofBar } from '../../components/home/proof-bar';

export default function HomePage() {
  return (
    <>
      <Hero />
      <PhraseMarquee />
      <ProofBar />
      <ProblemSection />
    </>
  );
}
