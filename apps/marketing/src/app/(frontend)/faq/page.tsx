import type { Metadata } from 'next';

import { FaqCta } from '../../../components/faq/faq-cta';
import { FaqGroups } from '../../../components/faq/faq-groups';
import { FaqHero } from '../../../components/faq/faq-hero';
import { getFaqPageGroups } from '../../../lib/faq';
import { JsonLd } from '../../../lib/seo/json-ld';
import { buildFaqPageNode } from '../../../lib/seo/jsonld';

import type { FaqSchemaInput } from '../../../lib/seo/jsonld';

// No brief copy exists to author /faq meta/OG from (NA-39 spec: "Enhancing
// /faq meta/OG copy" is out of scope) — the existing NA-38 metadata is
// unchanged; this page only gains FAQPage JSON-LD below.
export const metadata: Metadata = {
  title: 'FAQ — Everything builders ask',
  description:
    'Answers to the questions builders ask about Nightshift — positioning, workflow & control, setup & stack, trust & quality, and cost & license.',
};

// A Payload Local API read below would otherwise make this route attempt
// static prerendering at `next build` time, which requires a migrated
// Postgres schema to exist (NA-16 memory). force-dynamic also means the
// page reflects CMS edits immediately, with no redeploy.
export const dynamic = 'force-dynamic';

// Async page — the single top-level boundary where the Payload fetch
// happens (NA-16 memory: a second nested async Server Component breaks
// RTL's render()). Every section below stays a plain synchronous
// server/client component, receiving already-resolved data.
export default async function FaqPage() {
  const groups = await getFaqPageGroups();

  // Same already-resolved `answer` FaqGroups renders below — text-identity
  // guarantee (AC4). Flatten every group's items into one FAQPage node.
  const faqInputs: FaqSchemaInput[] = groups.flatMap((group) =>
    group.items.map((item) => ({
      question: item.question,
      answer: item.answer,
    })),
  );
  const faqNode = buildFaqPageNode(
    'https://github.com/whimzyLive/nightshift-ai/faq#faq',
    faqInputs,
  );

  return (
    <>
      {faqNode && (
        <JsonLd
          graph={{ '@context': 'https://schema.org', '@graph': [faqNode] }}
        />
      )}
      <FaqHero />
      <FaqGroups groups={groups} />
      <FaqCta />
    </>
  );
}
