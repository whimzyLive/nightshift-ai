import { ArgumentRail } from '../../../components/why-sdlc/argument-rail';
import { Hero } from '../../../components/why-sdlc/hero';
import { PageCta } from '../../../components/why-sdlc/page-cta';
import { PageFaq } from '../../../components/why-sdlc/page-faq';
import { ScrollProgressProvider } from '../../../components/why-sdlc/scroll-progress';
import { getWhySdlcContent, getWhySdlcFaqs } from '../../../lib/why-sdlc';

// Payload's Local API calls below would otherwise make this route attempt
// static prerendering at `next build` time, which requires a migrated
// Postgres schema to exist (NA-16 memory). force-dynamic also means the
// page reflects CMS edits immediately, with no redeploy.
export const dynamic = 'force-dynamic';

// Async page — the single top-level boundary where both Payload fetches
// happen (see NA-16 memory: a second nested async Server Component breaks
// RTL's render()). Every section below stays a plain synchronous
// server/client component, receiving already-resolved data.
export default async function WhySdlcPage() {
  const [content, faqs] = await Promise.all([
    getWhySdlcContent(),
    getWhySdlcFaqs(),
  ]);

  return (
    <>
      <Hero intro={content?.intro ?? null} />
      <ScrollProgressProvider>
        <ArgumentRail args={content?.arguments ?? []} />
        <PageFaq faqs={faqs} />
        <PageCta />
      </ScrollProgressProvider>
    </>
  );
}
