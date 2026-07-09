import type { CollectionConfig } from 'payload';

export const Users: CollectionConfig = {
  slug: 'users',
  admin: {
    useAsTitle: 'email',
  },
  auth: {
    // API keys let AI agents create/update content programmatically.
    useAPIKey: true,
  },
  fields: [],
};
