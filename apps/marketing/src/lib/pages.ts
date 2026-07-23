import { cache } from 'react';

import config from '@payload-config';
import { getPayload } from 'payload';

import type { Page } from '../payload-types';

export interface PageContent {
  title: Page['title'];
  content: Page['content'];
}

export const getPageBySlug = cache(
  async (slug: string): Promise<PageContent | null> => {
    const payload = await getPayload({ config });
    const { docs } = await payload.find({
      collection: 'pages',
      where: {
        and: [{ slug: { equals: slug } }, { _status: { equals: 'published' } }],
      },
      limit: 1,
      depth: 1,
    });
    const doc = docs[0];
    if (!doc) return null;
    return { title: doc.title, content: doc.content };
  },
);

export async function getPublishedPageSlugs(): Promise<
  Array<{ slug: string }>
> {
  try {
    const payload = await getPayload({ config });
    const { docs } = await payload.find({
      collection: 'pages',
      where: { _status: { equals: 'published' } },
      limit: 1000,
      depth: 0,
      select: { slug: true },
    });
    return docs.map((doc) => ({ slug: doc.slug }));
  } catch (error) {
    console.error('[pages]', error);
    return [];
  }
}
