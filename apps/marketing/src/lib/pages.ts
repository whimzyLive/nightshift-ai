import config from '@payload-config';
import { getPayload } from 'payload';

import type { Page } from '../payload-types';

export interface PageContent {
  title: Page['title'];
  content: Page['content'];
}

/**
 * The published page for `slug`, or null when none matches (route then calls
 * notFound()). depth: 1 populates each `media` block's Media upload (url/alt)
 * and any inline richText upload — depth 0 would leave a bare id and render
 * broken images. Graceful null on any Payload/DB error (lib/faq.ts convention).
 */
export async function getPageBySlug(slug: string): Promise<PageContent | null> {
  try {
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
  } catch (error) {
    console.error('[pages]', error);
    return null;
  }
}

/**
 * Published slugs for generateStaticParams. depth: 0 + select slug reads slugs
 * only (no relationships). Returns [] on any build-time DB failure so the build
 * still succeeds and dynamicParams covers first-hit rendering (NA-16 memory).
 */
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
