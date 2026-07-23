import type { CollectionConfig } from 'payload';

import { revalidatePage } from '../hooks/revalidatePage';

/** The four hand-built static routes an editor must not shadow with a CMS page. */
const RESERVED_SLUGS = ['home', 'faq', 'team', 'why-sdlc'];

export const Pages: CollectionConfig = {
  slug: 'pages',
  admin: {
    useAsTitle: 'title',
    group: 'Content',
    defaultColumns: ['title', 'slug', '_status'],
  },
  versions: {
    drafts: true,
  },
  access: {
    read: () => true,
    create: ({ req: { user } }) => Boolean(user),
    update: ({ req: { user } }) => Boolean(user),
    delete: ({ req: { user } }) => Boolean(user),
  },
  hooks: {
    afterChange: [revalidatePage],
  },
  fields: [
    {
      name: 'slug',
      type: 'text',
      required: true,
      unique: true,
      index: true,
      validate: (value: unknown) => {
        if (typeof value === 'string' && RESERVED_SLUGS.includes(value)) {
          return `"${value}" is a reserved route and cannot be used as a page slug.`;
        }
        return true;
      },
      admin: {
        description:
          'URL path segment — the page is served at /{slug}. Reserved: home, faq, team, why-sdlc.',
      },
    },
    {
      name: 'title',
      type: 'text',
      required: true,
    },
    {
      name: 'content',
      type: 'blocks',
      required: true,
      minRows: 1,
      blocks: [
        {
          slug: 'richText',
          fields: [{ name: 'richText', type: 'richText', required: true }],
        },
        {
          slug: 'media',
          fields: [
            {
              name: 'media',
              type: 'upload',
              relationTo: 'media',
              required: true,
            },
            { name: 'caption', type: 'text' },
          ],
        },
      ],
    },
  ],
};
