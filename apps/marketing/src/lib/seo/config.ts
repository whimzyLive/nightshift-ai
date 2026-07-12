/**
 * Frozen SEO config constants — single source for absolute URLs.
 * Values verbatim from docs/gtm/site-brief.md §3/§4. Canonical host stays
 * the GitHub repo per the brief's open decision #3 (host-swap deferred).
 */
export interface SeoSite {
  readonly siteUrl: string;
  readonly siteName: string;
  readonly ogImageHome: string;
  readonly ogImageWhySdlc: string;
}

export const seoSite = {
  siteUrl: 'https://github.com/whimzyLive/nightshift-ai',
  siteName: 'nightshift',
  ogImageHome:
    'https://raw.githubusercontent.com/whimzyLive/nightshift-ai/main/og-image.png',
  ogImageWhySdlc:
    'https://raw.githubusercontent.com/whimzyLive/nightshift-ai/main/og-why-sdlc.png',
} as const satisfies SeoSite;
