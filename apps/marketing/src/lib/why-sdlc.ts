import config from '@payload-config';
import { getPayload } from 'payload';

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
 * The `whySdlc` global — intro block + the five argument sections. Falls
 * back to `null` on any Payload/DB failure (NA-16 findGlobal convention) so
 * the hero/argument sections simply render nothing rather than throwing.
 */
export async function getWhySdlcContent(): Promise<WhySdlcContent | null> {
  try {
    const payload = await getPayload({ config });
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
  } catch (error) {
    console.error('[why-sdlc]', error);
    return null;
  }
}

/**
 * The 2-question page FAQ, ordered by `whySdlcOrder`. `whySdlcAnswer` (the
 * page-tuned richText override) wins over `answer` when set — mirrors
 * `getHomeFaqs`'s `homeAnswer` convention (see faq.ts). Falls back to an
 * empty list on any Payload/DB failure.
 */
export async function getWhySdlcFaqs(): Promise<WhySdlcFaqItem[]> {
  try {
    const payload = await getPayload({ config });
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
  } catch (error) {
    console.error('[why-sdlc]', error);
    return [];
  }
}
