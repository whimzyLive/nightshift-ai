import type { MetadataRoute } from 'next';

/**
 * Explicitly allows the AI-crawler user agents named in the site brief (§5)
 * so nightshift can be cited by AI search/answer engines, alongside the
 * default allow-all for traditional search crawlers.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      { userAgent: '*', allow: '/' },
      { userAgent: 'GPTBot', allow: '/' },
      { userAgent: 'ClaudeBot', allow: '/' },
      { userAgent: 'PerplexityBot', allow: '/' },
      { userAgent: 'Google-Extended', allow: '/' },
    ],
  };
}
