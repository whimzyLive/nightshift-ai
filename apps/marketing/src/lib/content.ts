import { cache } from 'react';

import type { SiteSetting, Home, WhySdlc } from '../payload-types';
import { getPayloadClient } from './payload';
import { SITE_SETTINGS_SLUG, HOME_SLUG, WHY_SDLC_SLUG } from '../globals/slugs';

// React `cache()` dedupes identical calls within a single request (layout +
// page both call getSiteSettings) — without it every render issues its own
// Postgres query for the same global. Each helper also degrades gracefully:
// a Neon outage used to 500 the whole route (or fail the build); catching
// the rejection and returning `{}` lets pages render via their existing
// `content?.field` empty-content guards instead.
export const getSiteSettings = cache(async (): Promise<SiteSetting> => {
  try {
    const payload = await getPayloadClient();
    return await payload.findGlobal({ slug: SITE_SETTINGS_SLUG });
  } catch (error) {
    console.error('[content] failed to load site settings', error);
    return {} as SiteSetting;
  }
});

export const getHomeContent = cache(async (): Promise<Home> => {
  try {
    const payload = await getPayloadClient();
    return await payload.findGlobal({ slug: HOME_SLUG });
  } catch (error) {
    console.error('[content] failed to load home content', error);
    return {} as Home;
  }
});

export const getWhySdlcContent = cache(async (): Promise<WhySdlc> => {
  try {
    const payload = await getPayloadClient();
    return await payload.findGlobal({ slug: WHY_SDLC_SLUG });
  } catch (error) {
    console.error('[content] failed to load why-sdlc content', error);
    return {} as WhySdlc;
  }
});
