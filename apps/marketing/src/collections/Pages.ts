import type { CollectionConfig } from 'payload';

import {
  revalidatePage,
  revalidatePageOnDelete,
} from '../hooks/revalidatePage';

const RESERVED_SLUGS = ['home', 'faq', 'team', 'why-sdlc'];
const SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export function validateSlug(value: unknown): string | true {
  if (typeof value !== 'string') return true;
  if (RESERVED_SLUGS.includes(value.toLowerCase())) {
    return `"${value}" is a reserved route and cannot be used as a page slug.`;
  }
  if (!SLUG_PATTERN.test(value)) {
    return `"${value}" must be lowercase letters, numbers, and hyphens only (e.g. "my-page").`;
  }
  return true;
}

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
    afterDelete: [revalidatePageOnDelete],
  },
  fields: [
    {
      name: 'slug',
      type: 'text',
      required: true,
      unique: true,
      index: true,
      validate: validateSlug,
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
