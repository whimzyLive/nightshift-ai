import { CursorGlow, Footer, NavBar, NightSky } from '@nightshift-ai/ui';
import type { Metadata } from 'next';
import type { ReactNode } from 'react';

import { interSans, jetbrainsMono } from '../../lib/fonts';
import '../global.css';

export const metadata: Metadata = {
  title: 'nightshift — your AI software team that ships while you sleep',
  description: 'Your AI software team that ships while you sleep.',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html
      lang="en"
      className={`${interSans.variable} ${jetbrainsMono.variable}`}
    >
      <body className="min-h-screen bg-[var(--bg-page)] text-[var(--text-body)] antialiased">
        <NightSky />
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
