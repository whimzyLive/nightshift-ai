import config from '@payload-config';
import { getPayload } from 'payload';

import type { Faq } from '../payload-types';

export interface HomeFaqItem {
  id: Faq['id'];
  question: Faq['question'];
  answer: Faq['answer'];
}

/**
 * Top-5 FAQs for the home preview accordion, ordered by `homeOrder`.
 * `homeAnswer` (the shorter, home-tuned copy) wins over `answer` when set —
 * mirrors the seed data's own convention (see seed/data.ts). Falls back to
 * an empty list on any Payload/DB failure so the section simply renders
 * nothing rather than throwing (same convention as the NA-16 findGlobal
 * fallback).
 */
export async function getHomeFaqs(): Promise<HomeFaqItem[]> {
  try {
    const payload = await getPayload({ config });
    const { docs } = await payload.find({
      collection: 'faq',
      where: { showOnHome: { equals: true } },
      sort: 'homeOrder',
      limit: 5,
      depth: 0,
    });

    return docs.map((doc) => ({
      id: doc.id,
      question: doc.question,
      answer: doc.homeAnswer ?? doc.answer,
    }));
  } catch (error) {
    console.error('[faq]', error);
    return [];
  }
}
