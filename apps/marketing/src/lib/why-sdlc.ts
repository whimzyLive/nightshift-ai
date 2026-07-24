import config from '@payload-config';
import { getPayload } from 'payload';

import { isDbConfigured, warnDbNotConfiguredOnce } from './db-config';
import { withDbFallback } from './with-db-fallback';

import type { Faq, WhySdlc } from '../payload-types';

export interface WhySdlcArgument {
  eyebrow: WhySdlc['arguments'][number]['eyebrow'];
  heading: WhySdlc['arguments'][number]['heading'];
  body: WhySdlc['arguments'][number]['body'];
}

export interface WhySdlcIntro {
  eyebrow: WhySdlc['intro']['eyebrow'];
  heading: WhySdlc['intro']['heading'];
  lead: WhySdlc['intro']['lead'];
  scrollHint: WhySdlc['intro']['scrollHint'];
}

export interface WhySdlcContent {
  intro: WhySdlcIntro;
  arguments: WhySdlcArgument[];
}

export interface WhySdlcFaqItem {
  id: Faq['id'];
  question: Faq['question'];
  answer: Faq['answer'];
}

/**
 * The `whySdlc` global — intro block + the five argument sections. Rethrows
 * on a connection/init failure so a DB outage fails the build; swallows an
 * isolated row-level defect to `null` so the hero/argument sections simply
 * render nothing. Short-circuits to `null` (no connection attempt) when
 * `DATABASE_URL` isn't configured — e.g. a CI build without secrets.
 */
export async function getWhySdlcContent(): Promise<WhySdlcContent | null> {
  if (!isDbConfigured()) {
    warnDbNotConfiguredOnce();
    return null;
  }

  const payload = await getPayload({ config });

  return withDbFallback('[why-sdlc]', null, async () => {
    const global = await payload.findGlobal({ slug: 'whySdlc', depth: 0 });

    return {
      intro: {
        eyebrow: global.intro.eyebrow,
        heading: global.intro.heading,
        lead: global.intro.lead,
        scrollHint: global.intro.scrollHint,
      },
      arguments: global.arguments.map((row) => ({
        eyebrow: row.eyebrow,
        heading: row.heading,
        body: row.body,
      })),
    };
  });
}

/**
 * The 2-question page FAQ, ordered by `whySdlcOrder`. `whySdlcAnswer` (the
 * page-tuned richText override) wins over `answer` when set — mirrors
 * `getHomeFaqs`'s `homeAnswer` convention (see faq.ts). Rethrows on a
 * connection/init failure so a DB outage fails the build; swallows an
 * isolated row-level defect to an empty list. Short-circuits to the empty
 * fallback (no connection attempt) when `DATABASE_URL` isn't configured.
 */
export async function getWhySdlcFaqs(): Promise<WhySdlcFaqItem[]> {
  if (!isDbConfigured()) {
    warnDbNotConfiguredOnce();
    return [];
  }

  const payload = await getPayload({ config });

  return withDbFallback('[why-sdlc]', [], async () => {
    const { docs } = await payload.find({
      collection: 'faq',
      where: { showOnWhySdlc: { equals: true } },
      sort: 'whySdlcOrder',
      limit: 2,
      depth: 0,
    });

    return docs.map((doc) => ({
      id: doc.id,
      question: doc.question,
      answer: doc.whySdlcAnswer ?? doc.answer,
    }));
  });
}
