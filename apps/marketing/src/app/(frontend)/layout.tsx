import { CursorGlow, Footer, NavBar } from '@nightshift-ai/ui';
import type { Metadata } from 'next';
import type { ReactNode } from 'react';

import { seoSite } from '../../lib/seo/config';
import { interSans, jetbrainsMono } from '../../lib/fonts';
import '../global.css';

// metadataBase lets every page's relative canonical/OG/Twitter URLs (see
// lib/seo/metadata.ts) resolve to absolute URLs (AC5). Default
// openGraph.siteName/twitter.card fall through for routes with no metadata
// override of their own (e.g. /team).
export const metadata: Metadata = {
  metadataBase: new URL(seoSite.siteUrl),
  title: 'nightshift — your AI software team that ships while you sleep',
  description: 'Your AI software team that ships while you sleep.',
  openGraph: {
    siteName: seoSite.siteName,
  },
  twitter: {
    card: 'summary_large_image',
  },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html
      lang="en"
      className={`${interSans.variable} ${jetbrainsMono.variable}`}
    >
      <body className="min-h-screen bg-[var(--bg-page)] text-[var(--text-body)] antialiased">
        <CursorGlow />
        <NavBar />
        <main
          className="mx-auto max-w-[var(--container-max)] px-7"
          style={{ paddingTop: 'var(--nav-height)' }}
        >
          {children}
        </main>
        <Footer />
      </body>
    </html>
  );
}
