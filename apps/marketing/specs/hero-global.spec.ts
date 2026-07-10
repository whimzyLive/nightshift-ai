// Hero.ts (a Payload GlobalConfig) imports revalidateHero, which imports
// `next/cache` — that module reaches for `TextEncoder` at import time, which
// isn't defined in the jsdom test environment. Mock it so importing Hero.ts
// here only exercises validateCtaHref, not the real revalidation hook.
jest.mock('next/cache', () => ({
  revalidatePath: jest.fn(),
  revalidateTag: jest.fn(),
}));

import { validateCtaHref } from '../src/globals/Hero';

describe('validateCtaHref', () => {
  it('accepts an absolute https URL', () => {
    expect(validateCtaHref('https://example.com')).toBe(true);
  });

  it('accepts an absolute http URL', () => {
    expect(validateCtaHref('http://example.com')).toBe(true);
  });

  it('accepts a single-slash relative path', () => {
    expect(validateCtaHref('/pricing')).toBe(true);
  });

  it('accepts a relative path with surrounding whitespace after trimming', () => {
    expect(validateCtaHref('  /pricing  ')).toBe(true);
  });

  it('rejects a missing value', () => {
    expect(validateCtaHref(undefined)).toBe('CTA URL is required.');
  });

  it('rejects an empty string', () => {
    expect(validateCtaHref('')).toBe('CTA URL is required.');
  });

  it('rejects a whitespace-only value', () => {
    expect(validateCtaHref('   ')).toBe('CTA URL is required.');
  });

  it('rejects a scheme-relative URL that would navigate off-site', () => {
    expect(validateCtaHref('//evil.example')).toBe(
      'CTA URL must be an absolute http(s) URL or a relative path (e.g. /pricing).',
    );
  });

  it('rejects a javascript: URL', () => {
    expect(validateCtaHref('javascript:alert(1)')).toBe(
      'CTA URL must be an absolute http(s) URL or a relative path (e.g. /pricing).',
    );
  });
});
