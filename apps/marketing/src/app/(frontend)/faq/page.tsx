import type { Metadata } from 'next';

import { FaqCta } from '../../../components/faq/faq-cta';
import { FaqGroups } from '../../../components/faq/faq-groups';
import { FaqHero } from '../../../components/faq/faq-hero';
import { getFaqPageGroups } from '../../../lib/faq';

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
  return (
    <>
      <FaqHero />
      <FaqGroups groups={groups} />
      <FaqCta />
    </>
  );
}
