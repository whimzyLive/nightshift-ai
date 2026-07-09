//@ts-check
const path = require('path');

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Pin the workspace root so Turbopack does not infer it from sibling lockfiles.
  turbopack: {
    root: path.join(__dirname, '../..'),
  },
  // See: https://nextjs.org/docs/app/api-reference/config/next-config-js
};

module.exports = nextConfig;
