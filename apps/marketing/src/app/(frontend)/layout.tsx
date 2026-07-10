import type { Metadata } from 'next';
import { Inter, JetBrains_Mono } from 'next/font/google';

import '../global.css';
import { getSiteSettings } from '../../lib/content';
import { SiteHeader } from './_components/SiteHeader';
import { SiteFooter } from './_components/SiteFooter';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});
const jetbrains = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-jetbrains-mono',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'nightshift',
  description: 'Your AI software team that ships while you sleep.',
};

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const siteSettings = await getSiteSettings();
  return (
    <html lang="en" className={`${inter.variable} ${jetbrains.variable}`}>
      <body className="bg-page font-sans text-body antialiased">
        <SiteHeader siteSettings={siteSettings} />
        {children}
        <SiteFooter siteSettings={siteSettings} />
      </body>
    </html>
  );
}
