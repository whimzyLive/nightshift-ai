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
  // sharp is a serverExternalPackage (via withPayload), so Next.js file tracing
  // follows its JS entry but cannot follow the dlopen'd native chain:
  // sharp-linux-x64/sharp.node loads libvips-cpp.so via ELF RPATH from the
  // sibling @img/sharp-libvips-linux-x64 package — invisible to nft, so the .so
  // never ships and every sharp call 500s on Vercel with ERR_DLOPEN_FAILED.
  // Force-include every @img package from both the hoisted root node_modules
  // (see root .npmrc public-hoist-pattern) and the pnpm virtual store.
  outputFileTracingIncludes: {
    '**/*': [
      '../../node_modules/@img/**/*',
      '../../node_modules/.pnpm/@img+*/node_modules/@img/**/*',
    ],
  },
  // See: https://nextjs.org/docs/app/api-reference/config/next-config-js
};

export default withPayload(nextConfig);
