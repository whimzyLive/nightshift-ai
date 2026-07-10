import { revalidatePath } from 'next/cache';
import type { CollectionAfterChangeHook, GlobalAfterChangeHook } from 'payload';

// Publishing or editing in the admin updates the live site through ISR
// revalidation — no redeploy involved.
export const revalidatePage: CollectionAfterChangeHook = ({ doc, req }) => {
  if (doc._status === 'published') {
    const path = doc.slug === 'home' ? '/' : `/${doc.slug}`;
    req.payload.logger.info(`Revalidating page at ${path}`);
    revalidatePath(path);
  }
  return doc;
};

export const revalidatePost: CollectionAfterChangeHook = ({ doc, req }) => {
  if (doc._status === 'published') {
    req.payload.logger.info(`Revalidating post at /blog/${doc.slug}`);
    revalidatePath(`/blog/${doc.slug}`);
    revalidatePath('/blog');
  }
  return doc;
};

// The homepage route (apps/marketing/src/app/(marketing)/page.tsx) is
// `export const dynamic = 'force-dynamic'`, so it's never cached and this
// revalidatePath('/') is currently a no-op — there's nothing to invalidate.
// Kept (not deleted) so hero edits start revalidating meaningfully the
// moment that route ever moves off force-dynamic onto an ISR/cached
// strategy; delete this hook only alongside a decision that force-dynamic
// is permanent.
export const revalidateHero: GlobalAfterChangeHook = ({ req }) => {
  req.payload.logger.info('Revalidating homepage hero at /');
  revalidatePath('/');
};
