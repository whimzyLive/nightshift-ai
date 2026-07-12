import { seoSite } from './config';

import type { Metadata } from 'next';

// Meta/OG/Twitter copy verbatim from docs/gtm/site-brief.md §4. Relative
// `alternates.canonical`/`openGraph.url` values resolve against
// `metadataBase` (set once in the frontend layout — see layout.tsx).
export const homeMetadata: Metadata = {
  title: 'nightshift — your AI software team that ships while you sleep',
  description:
    'nightshift is a free, MIT-licensed Claude Code plugin that runs your whole SDLC. It reads a Jira ticket and ships the spec, plan, code, and review automatically.',
  alternates: {
    canonical: '/',
  },
  openGraph: {
    type: 'website',
    title: 'Your AI software team that ships while you sleep',
    description:
      'A Claude Code plugin that turns one terminal into a full delivery team — PM, architect, tech lead, engineers, QA. Ticket in, reviewed PR out. Free and MIT.',
    url: '/',
    images: [
      {
        url: seoSite.ogImageHome,
        alt: 'nightshift pipeline: Jira ticket to spec to plan to implementation to review to PR',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Your AI software team that ships while you sleep',
    description:
      'A Claude Code plugin that runs your whole SDLC — spec, plan, code, review — from one ticket. Free and MIT.',
    images: [
      {
        url: seoSite.ogImageHome,
        alt: 'nightshift pipeline: Jira ticket to spec to plan to implementation to review to PR',
      },
    ],
  },
};

export const whySdlcMetadata: Metadata = {
  title: 'Why nightshift keeps you in control of AI-built code',
  description:
    'Most AI dev tools abstract the process away. nightshift enforces the software development lifecycle instead: a hard gate at every phase keeps you in control.',
  alternates: {
    canonical: '/why-sdlc',
  },
  openGraph: {
    type: 'article',
    title: 'You decide how it gets built — not the other way around',
    description:
      'Frameworks, meta-frameworks, and meta-prompts do everything for you and take control with it. nightshift puts the SDLC back in front of you, with a hard gate at every phase.',
    url: '/why-sdlc',
    images: [
      {
        url: seoSite.ogImageWhySdlc,
        alt: 'nightshift phases with a hard gate returning control at each: refine, spec, plan, implement, review',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'You decide how it gets built — not the other way around',
    description:
      'nightshift enforces the SDLC when you work with AI agents. A hard gate at every phase returns control before the next step runs. Free and MIT.',
    images: [
      {
        url: seoSite.ogImageWhySdlc,
        alt: 'nightshift phases with a hard gate returning control at each: refine, spec, plan, implement, review',
      },
    ],
  },
};
