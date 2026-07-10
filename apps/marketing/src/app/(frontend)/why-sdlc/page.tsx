import Link from 'next/link';
import { getWhySdlcContent, getSiteSettings } from '../../../lib/content';
import { WhySdlcHero } from '../_components/WhySdlcHero';
import { ArgumentSection } from '../_components/ArgumentSection';
import { WhySdlcFaq } from '../_components/WhySdlcFaq';
import { FinalCta } from '../_components/FinalCta';

export const revalidate = 60;

export default async function WhySdlcPage() {
  const [content, siteSettings] = await Promise.all([
    getWhySdlcContent(),
    getSiteSettings(),
  ]);
  return (
    <main className="mx-auto max-w-4xl px-6 py-16">
      <nav aria-label="Breadcrumb" className="mb-8 font-mono text-xs text-dim">
        <Link href="/">Home</Link> <span aria-hidden>&gt;</span> Why SDLC
      </nav>
      <WhySdlcHero content={content?.hero} />
      {(content?.argumentSections ?? []).map((s, i) => (
        <ArgumentSection key={s.id ?? i} content={s} />
      ))}
      <WhySdlcFaq content={content?.faq} />
      <FinalCta content={content?.finalCta} siteSettings={siteSettings} />
    </main>
  );
}
