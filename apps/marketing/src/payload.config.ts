import path from 'path';
import { fileURLToPath } from 'url';

import { postgresAdapter } from '@payloadcms/db-postgres';
import { lexicalEditor } from '@payloadcms/richtext-lexical';
import { buildConfig } from 'payload';
import sharp from 'sharp';

import { Faq } from './collections/Faq';
import { Media } from './collections/Media';
import { Users } from './collections/Users';
import { WhySdlc } from './globals/WhySdlc';

const filename = fileURLToPath(import.meta.url);
const dirname = path.dirname(filename);

export default buildConfig({
  admin: {
    user: Users.slug,
    importMap: {
      baseDir: path.resolve(dirname),
    },
    components: {
      graphics: {
        Icon: '/components/admin/icon#Icon',
        Logo: '/components/admin/logo#Logo',
      },
    },
    meta: {
      title: 'nightshift admin',
      titleSuffix: ' — nightshift',
      description:
        'Content and configuration for the nightshift marketing site.',
      icons: [{ url: '/favicon.svg', type: 'image/svg+xml' }],
      openGraph: {
        title: 'nightshift admin',
        description:
          'Content and configuration for the nightshift marketing site.',
      },
    },
  },
  collections: [Faq, Media, Users],
  globals: [WhySdlc],
  editor: lexicalEditor(),
  secret: process.env.PAYLOAD_SECRET || '',
  db: postgresAdapter({
    pool: {
      connectionString: process.env.DATABASE_URL || '',
    },
  }),
  sharp,
  typescript: {
    outputFile: path.resolve(dirname, 'payload-types.ts'),
  },
});
