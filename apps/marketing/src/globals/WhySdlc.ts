import type { GlobalConfig } from 'payload';

export const WhySdlc: GlobalConfig = {
  slug: 'whySdlc',
  admin: {
    group: 'Content',
  },
  access: {
    read: () => true,
    update: ({ req: { user } }) => Boolean(user),
  },
  fields: [
    {
      name: 'intro',
      type: 'group',
      required: true,
      fields: [
        {
          name: 'eyebrow',
          type: 'text',
          required: true,
        },
        {
          name: 'heading',
          type: 'text',
          required: true,
        },
        {
          name: 'lead',
          type: 'richText',
          required: true,
        },
        {
          name: 'scrollHint',
          type: 'text',
          required: true,
        },
      ],
    },
    {
      name: 'arguments',
      type: 'array',
      required: true,
      minRows: 5,
      maxRows: 5,
      fields: [
        {
          name: 'eyebrow',
          type: 'text',
          required: true,
        },
        {
          name: 'heading',
          type: 'text',
          required: true,
        },
        {
          name: 'body',
          type: 'richText',
          required: true,
        },
      ],
    },
  ],
};
