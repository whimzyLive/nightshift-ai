import type { CollectionConfig } from 'payload';

import { revalidatePage } from '../hooks/revalidate';

export const Pages: CollectionConfig = {
  slug: 'pages',
  admin: {
    useAsTitle: 'title',
    defaultColumns: ['title', 'slug', 'updatedAt'],
  },
  access: {
    // Published pages are public; drafts require auth.
    read: ({ req }) => {
      if (req.user) return true;
      return { _status: { equals: 'published' } };
    },
  },
  versions: {
    drafts: true,
    maxPerDoc: 25,
  },
  hooks: {
    afterChange: [revalidatePage],
  },
  fields: [
    {
      name: 'title',
      type: 'text',
      required: true,
    },
    {
      name: 'slug',
      type: 'text',
      required: true,
      unique: true,
      index: true,
      admin: {
        description: 'URL path segment. Use "home" for the landing page.',
      },
    },
    {
      name: 'content',
      type: 'richText',
    },
  ],
};
