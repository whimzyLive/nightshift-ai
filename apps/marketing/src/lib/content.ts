import type { SiteSetting, Home, WhySdlc } from '../payload-types';
import { getPayloadClient } from './payload';
import { SITE_SETTINGS_SLUG, HOME_SLUG, WHY_SDLC_SLUG } from '../globals/slugs';

export async function getSiteSettings(): Promise<SiteSetting> {
  const payload = await getPayloadClient();
  return payload.findGlobal({ slug: SITE_SETTINGS_SLUG });
}
export async function getHomeContent(): Promise<Home> {
  const payload = await getPayloadClient();
  return payload.findGlobal({ slug: HOME_SLUG });
}
export async function getWhySdlcContent(): Promise<WhySdlc> {
  const payload = await getPayloadClient();
  return payload.findGlobal({ slug: WHY_SDLC_SLUG });
}
