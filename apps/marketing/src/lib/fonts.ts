import { Inter, JetBrains_Mono } from 'next/font/google';

// Self-hosted via next/font (build-time fetch + local serving, no runtime
// Google Fonts request) — see docs/design/marketing-site-handoff/tokens/fonts.css
// for the tokens this replaces. Weights match the design handoff scale.
// The `variable` names are private ingredients — `global.css`'s `@theme`
// composes them into the `--font-sans`/`--font-mono` tokens the design
// system expects, with the token files' system-font fallback stacks.
export const interSans = Inter({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700', '800'],
  variable: '--font-inter',
  display: 'swap',
});

export const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  weight: ['400', '500', '700'],
  style: ['normal', 'italic'],
  variable: '--font-jetbrains-mono',
  display: 'swap',
});
