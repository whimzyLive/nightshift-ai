// Shared between src/globals/Hero.ts (field defaultValue) and
// get-hero-content.ts (fallback when the `hero` global can't be read) — one
// source of truth for "the homepage hero renders correctly with no CMS
// edits and no reachable DB". Deliberately dependency-free: get-hero-content
// must be able to import this without pulling in Hero.ts's revalidate hook
// (which imports next/cache, unusable outside a request context).
export const heroFieldDefaults = {
  headline: 'Your AI software team that ships while you sleep',
  subhead:
    'A Claude Code plugin that turns one terminal into a full delivery team — product manager, architect, tech lead, engineers, and QA. It reads a Jira ticket and ships the spec, plan, code, and review.',
  ctaLabel: 'Install the plugin',
  ctaHref: 'https://github.com/whimzyLive/nightshift-ai',
} as const;
