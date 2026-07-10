import { getPayload } from 'payload';

import config from '@payload-config';

import type { Hero } from '../payload-types';

// Server-only data access for the homepage hero global. Payload returns the
// field defaultValue set even before an editor has saved a document, so this
// never throws on a fresh install.
export async function getHeroContent(): Promise<Hero> {
  const payload = await getPayload({ config });
  return payload.findGlobal({ slug: 'hero' });
}
