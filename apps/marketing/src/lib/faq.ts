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

type FaqGroup = Faq['group'];

export interface FaqPageItem {
  id: Faq['id'];
  question: Faq['question'];
  answer: Faq['answer'];
  /** Continuous 1-based page number for the Q.NN label (equals faqOrder). */
  number: number;
}

export interface FaqPageGroup {
  key: FaqGroup;
  eyebrow: string;
  items: FaqPageItem[];
}

/** Source of truth: the faq collection's `group` select option labels. */
const FAQ_GROUP_EYEBROW: Record<NonNullable<FaqGroup>, string> = {
  positioning: '// positioning',
  'workflow-control': '// workflow & control',
  'setup-stack': '// setup & stack',
  'trust-quality': '// trust & quality',
  'cost-license': '// cost & license',
};

/**
 * All FAQs for the standalone /faq page, ordered by `faqOrder`, partitioned
 * into topic groups in first-appearance order. Uses the full `answer` field
 * (not `homeAnswer`). Returns [] on any Payload/DB failure — same
 * graceful-empty convention as getHomeFaqs.
 */
export async function getFaqPageGroups(): Promise<FaqPageGroup[]> {
  try {
    const payload = await getPayload({ config });
    const { docs } = await payload.find({
      collection: 'faq',
      sort: 'faqOrder',
      limit: 100,
      depth: 0,
    });

    const groups: FaqPageGroup[] = [];
    const byKey = new Map<FaqGroup, FaqPageGroup>();

    for (const doc of docs) {
      let group = byKey.get(doc.group);
      if (!group) {
        group = {
          key: doc.group,
          eyebrow: FAQ_GROUP_EYEBROW[doc.group],
          items: [],
        };
        byKey.set(doc.group, group);
        groups.push(group);
      }
      group.items.push({
        id: doc.id,
        question: doc.question,
        answer: doc.answer,
        number: doc.faqOrder,
      });
    }

    return groups;
  } catch (error) {
    console.error('[faq]', error);
    return [];
  }
}
