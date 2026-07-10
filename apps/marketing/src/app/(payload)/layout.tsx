/* THIS FILE WAS GENERATED AUTOMATICALLY BY PAYLOAD. */
/* DO NOT MODIFY IT BECAUSE IT COULD BE REWRITTEN AT ANY TIME. */
import type { ServerFunctionClient } from 'payload';

import config from '@payload-config';
import '@payloadcms/next/css';
import { handleServerFunctions, RootLayout } from '@payloadcms/next/layouts';
import { Inter, JetBrains_Mono } from 'next/font/google';
import React from 'react';

import { importMap } from './admin/importMap.js';
import './custom.scss';

// Self-host the fonts custom.scss references (--font-body / --font-mono)
// the same way the (frontend) layout does — RootLayout's `htmlProps` is the
// supported extension point for adding classes to Payload's generated
// <html> element without hand-editing its markup.
const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});
const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-jetbrains-mono',
  display: 'swap',
});

type Args = {
  children: React.ReactNode;
};

const serverFunction: ServerFunctionClient = async function (args) {
  'use server';
  return handleServerFunctions({
    ...args,
    config,
    importMap,
  });
};

const Layout = ({ children }: Args) => (
  <RootLayout
    config={config}
    importMap={importMap}
    serverFunction={serverFunction}
    htmlProps={{ className: `${inter.variable} ${jetbrainsMono.variable}` }}
  >
    {children}
  </RootLayout>
);

export default Layout;
