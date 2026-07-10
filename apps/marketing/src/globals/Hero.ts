import type { GlobalConfig } from 'payload';

import { revalidateHero } from '../hooks/revalidate';
import { heroFieldDefaults } from '../lib/hero-defaults';

// Blocks `javascript:` and other script-executing URL schemes, and
// scheme-relative URLs (`//evil.example`) that would navigate off-site,
// from being rendered straight into the hero's `<a href>` — only allow
// absolute http(s) links or single-slash relative in-app paths.
export function validateCtaHref(value: string | null | undefined) {
  const trimmed = value?.trim();
  if (!trimmed) {
    return 'CTA URL is required.';
  }
  if (/^https?:\/\//i.test(trimmed) || /^\/(?!\/)/.test(trimmed)) {
    return true;
  }
  return 'CTA URL must be an absolute http(s) URL or a relative path (e.g. /pricing).';
}

// Single-instance hero content for the marketing homepage — editable in the
// Payload admin (Globals > Hero) without a code deploy. defaultValue on every
// field means the hero renders correctly before an editor ever touches it.
export const Hero: GlobalConfig = {
  slug: 'hero',
  label: 'Hero',
  access: {
    read: () => true,
  },
  hooks: {
    afterChange: [revalidateHero],
  },
  fields: [
    {
      name: 'headline',
      type: 'text',
      required: true,
      defaultValue: heroFieldDefaults.headline,
    },
    {
      name: 'subhead',
      type: 'textarea',
      required: true,
      defaultValue: heroFieldDefaults.subhead,
    },
    {
      name: 'ctaLabel',
      type: 'text',
      required: true,
      defaultValue: heroFieldDefaults.ctaLabel,
      admin: {
        description: 'Label for the hero call-to-action button.',
      },
    },
    {
      name: 'ctaHref',
      type: 'text',
      required: true,
      defaultValue: heroFieldDefaults.ctaHref,
      validate: validateCtaHref,
      admin: {
        description: 'URL the hero CTA button links to.',
      },
    },
  ],
};

export default Hero;
