import type { GlobalConfig } from 'payload';

import { revalidateHero } from '../hooks/revalidate';

// Single-instance hero content for the marketing homepage — editable in the
// Payload admin (Globals > Hero) without a code deploy. defaultValue on every
// field means the hero renders correctly before an editor ever touches it.
export const Hero: GlobalConfig = {
  slug: 'hero',
  label: 'Hero',
  access: {
    read: () => true,
  },
  hooks: {
    afterChange: [revalidateHero],
  },
  fields: [
    {
      name: 'headline',
      type: 'text',
      required: true,
      defaultValue: 'Your AI software team that ships while you sleep',
    },
    {
      name: 'subhead',
      type: 'textarea',
      required: true,
      defaultValue:
        'A Claude Code plugin that turns one terminal into a full delivery team — product manager, architect, tech lead, engineers, and QA. It reads a Jira ticket and ships the spec, plan, code, and review.',
    },
    {
      name: 'ctaLabel',
      type: 'text',
      required: true,
      defaultValue: 'Install the plugin',
      admin: {
        description: 'Label for the hero call-to-action button.',
      },
    },
    {
      name: 'ctaHref',
      type: 'text',
      required: true,
      defaultValue: 'https://github.com/whimzyLive/nightshift-ai',
      admin: {
        description: 'URL the hero CTA button links to.',
      },
    },
  ],
};

export default Hero;
