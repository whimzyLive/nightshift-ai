import type { GlobalConfig } from 'payload';

import { SITE_SETTINGS_SLUG } from './slugs';

export const SiteSettings: GlobalConfig = {
  slug: SITE_SETTINGS_SLUG,
  access: { read: () => true },
  fields: [
    { name: 'installCommand', type: 'text' },
    {
      name: 'githubUrl',
      type: 'text',
      defaultValue: 'https://github.com/whimzyLive/nightshift-ai',
    },
    {
      name: 'githubLabel',
      type: 'text',
      defaultValue: 'GitHub',
    },
    {
      name: 'navLinks',
      type: 'array',
      fields: [
        { name: 'label', type: 'text' },
        { name: 'href', type: 'text' },
      ],
    },
    {
      name: 'footerColumns',
      type: 'array',
      fields: [
        { name: 'heading', type: 'text' },
        {
          name: 'links',
          type: 'array',
          fields: [
            { name: 'label', type: 'text' },
            { name: 'href', type: 'text' },
          ],
        },
      ],
    },
  ],
};
