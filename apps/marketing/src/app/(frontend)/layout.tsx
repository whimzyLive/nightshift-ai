import type { Metadata } from 'next';

import '../global.css';

export const metadata: Metadata = {
  title: 'nightshift',
  description: 'Your AI software team that ships while you sleep.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
