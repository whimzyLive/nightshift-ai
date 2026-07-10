import { getPayload } from 'payload';

import config from '@payload-config';

import { heroFieldDefaults } from './hero-defaults';
import type { Hero } from '../payload-types';

export type HeroContent = Pick<
  Hero,
  'headline' | 'subhead' | 'ctaLabel' | 'ctaHref'
>;

// Server-only data access for the homepage hero global. Payload returns the
// field defaultValue set even before an editor has saved a document, so this
// never throws on a fresh install with a migrated schema. If the DB is
// unreachable, or the `hero` table doesn't exist yet because a schema
// push/migration hasn't run against this environment (see
// apps/marketing/README.md), fall back to the same defaults so the homepage
// degrades gracefully instead of 500ing.
export async function getHeroContent(): Promise<HeroContent> {
  try {
    const payload = await getPayload({ config });
    return await payload.findGlobal({ slug: 'hero' });
  } catch (error) {
    console.error(
      '[get-hero-content] Could not read the hero global — falling back to field defaults.',
      error,
    );
    return heroFieldDefaults;
  }
}
