import { ArgumentRail } from '../../../components/why-sdlc/argument-rail';
import { Hero } from '../../../components/why-sdlc/hero';
import { PageCta } from '../../../components/why-sdlc/page-cta';
import { PageFaq } from '../../../components/why-sdlc/page-faq';
import { ScrollProgressProvider } from '../../../components/why-sdlc/scroll-progress';
import { JsonLd } from '../../../lib/seo/json-ld';
import {
  buildFaqPageNode,
  whySdlcBreadcrumbNode,
  whySdlcWebPageNode,
} from '../../../lib/seo/jsonld';
import { whySdlcMetadata } from '../../../lib/seo/metadata';
import { getWhySdlcContent, getWhySdlcFaqs } from '../../../lib/why-sdlc';

import type { FaqSchemaInput } from '../../../lib/seo/jsonld';
import type { Metadata } from 'next';

export const metadata: Metadata = whySdlcMetadata;

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

  // Same already-resolved `answer` PageFaq renders below — text-identity
  // guarantee (AC4).
  const faqInputs: FaqSchemaInput[] = faqs.map((faq) => ({
    question: faq.question,
    answer: faq.answer,
  }));
  const faqNode = buildFaqPageNode(
    'https://github.com/whimzyLive/nightshift-ai/why-sdlc#faq',
    faqInputs,
  );

  return (
    <>
      <JsonLd
        graph={{
          '@context': 'https://schema.org',
          '@graph': [
            whySdlcWebPageNode,
            whySdlcBreadcrumbNode,
            ...(faqNode ? [faqNode] : []),
          ],
        }}
      />
      <Hero intro={content?.intro ?? null} />
      <ScrollProgressProvider>
        <ArgumentRail args={content?.arguments ?? []} />
        <PageFaq faqs={faqs} />
        <PageCta />
      </ScrollProgressProvider>
    </>
  );
}
