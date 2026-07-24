import config from '@payload-config';
import { getPayload } from 'payload';

import { isConnectionOrInitError } from './is-connection-error';

import type { Faq } from '../payload-types';

export interface HomeFaqItem {
  id: Faq['id'];
  question: Faq['question'];
  answer: Faq['answer'];
}

/**
 * Top-5 FAQs for the home preview accordion, ordered by `homeOrder`.
 * `homeAnswer` (the shorter, home-tuned copy) wins over `answer` when set —
 * mirrors the seed data's own convention (see seed/data.ts). Rethrows on a
 * connection/init failure so a DB outage fails the build; swallows an
 * isolated row-level defect to an empty list.
 */
export async function getHomeFaqs(): Promise<HomeFaqItem[]> {
  const payload = await getPayload({ config });

  try {
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
    if (isConnectionOrInitError(error)) throw error;
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
 * (not `homeAnswer`). Rethrows on a connection/init failure so a DB outage
 * fails the build; swallows an isolated row-level defect to an empty list —
 * same convention as getHomeFaqs.
 */
export async function getFaqPageGroups(): Promise<FaqPageGroup[]> {
  const payload = await getPayload({ config });

  try {
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
    if (isConnectionOrInitError(error)) throw error;
    console.error('[faq]', error);
    return [];
  }
}
