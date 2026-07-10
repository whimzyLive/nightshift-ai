import type { GlobalConfig } from 'payload';

import { WHY_SDLC_SLUG } from './slugs';

export const WhySdlc: GlobalConfig = {
  slug: WHY_SDLC_SLUG,
  access: { read: () => true },
  fields: [
    {
      name: 'hero',
      type: 'group',
      fields: [
        { name: 'eyebrow', type: 'text' },
        { name: 'h1', type: 'text' },
        { name: 'intro', type: 'richText' },
      ],
    },
    {
      name: 'argumentSections',
      type: 'array',
      fields: [
        { name: 'heading', type: 'text' },
        { name: 'body', type: 'richText' },
      ],
    },
    {
      name: 'faq',
      type: 'group',
      fields: [
        {
          name: 'items',
          type: 'array',
          fields: [
            { name: 'question', type: 'text' },
            { name: 'answer', type: 'richText' },
          ],
        },
      ],
    },
    {
      name: 'finalCta',
      type: 'group',
      fields: [
        { name: 'heading', type: 'text' },
        { name: 'body', type: 'text' },
      ],
    },
  ],
};
