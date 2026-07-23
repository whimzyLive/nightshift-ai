import { revalidatePath } from 'next/cache';

import type {
  CollectionAfterChangeHook,
  CollectionAfterDeleteHook,
} from 'payload';

export function slugToPath(slug: string): string {
  return `/${slug}`;
}

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

export const revalidatePageOnDelete: CollectionAfterDeleteHook = ({ doc }) => {
  try {
    if (doc?.slug) revalidatePath(slugToPath(doc.slug));
  } catch (error) {
    console.error('[revalidatePage]', error);
  }
  return doc;
};
