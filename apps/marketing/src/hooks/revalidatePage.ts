import { revalidatePath } from 'next/cache';

import type { CollectionAfterChangeHook } from 'payload';

/**
 * Single source of truth for the path the `[slug]` route serves a Pages doc at.
 * A doc with slug `s` renders at `/${s}` — deliberately NO `home` → `/`
 * special-case in this story (`home` is a reserved slug the collection
 * rejects; the hand-built root `/` is force-dynamic, so nothing to revalidate).
 */
export function slugToPath(slug: string): string {
  return `/${slug}`;
}

/**
 * Regenerates the edited page's static HTML on save via on-demand ISR.
 * `revalidatePath` is a synchronous, void-returning cache-invalidation call —
 * there is no promise to await. Any throw is caught + logged so a revalidation
 * failure can never fail the editor's save.
 */
export const revalidatePage: CollectionAfterChangeHook = ({
  doc,
  previousDoc,
}) => {
  try {
    revalidatePath(slugToPath(doc.slug));
    if (previousDoc?.slug && previousDoc.slug !== doc.slug) {
      revalidatePath(slugToPath(previousDoc.slug));
    }
  } catch (error) {
    console.error('[revalidatePage]', error);
  }
  return doc;
};
