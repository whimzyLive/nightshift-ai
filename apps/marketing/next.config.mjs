//@ts-check
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { withPayload } from '@payloadcms/next/withPayload';

const dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Pin the workspace root so Turbopack does not infer it from sibling lockfiles.
  turbopack: {
    root: path.join(dirname, '../..'),
  },
  // See: https://nextjs.org/docs/app/api-reference/config/next-config-js
};

export default withPayload(nextConfig);
