import { getHeroContent } from '../src/lib/get-hero-content';
import { heroFieldDefaults } from '../src/lib/hero-defaults';

const mockFindGlobal = jest.fn();
const mockGetPayload = jest.fn((..._args: unknown[]) =>
  Promise.resolve({ findGlobal: mockFindGlobal }),
);

jest.mock('payload', () => ({
  getPayload: (...args: unknown[]) => mockGetPayload(...args),
}));

// `@payload-config` is a tsconfig path alias, not a real package — next/jest
// doesn't wire it into Jest's module resolution, so it must be mocked as
// virtual. The fallback under test never needs a real Payload config.
jest.mock('@payload-config', () => ({ default: {} }), { virtual: true });

describe('getHeroContent', () => {
  let consoleErrorSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    consoleErrorSpy = jest
      .spyOn(console, 'error')
      .mockImplementation(() => undefined);
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
  });

  it('returns the live CMS document when the hero global can be read', async () => {
    mockFindGlobal.mockResolvedValue({
      headline: 'CMS headline',
      subhead: 'CMS subhead',
      ctaLabel: 'CMS CTA',
      ctaHref: 'https://example.com',
    });

    const hero = await getHeroContent();

    expect(hero).toEqual({
      headline: 'CMS headline',
      subhead: 'CMS subhead',
      ctaLabel: 'CMS CTA',
      ctaHref: 'https://example.com',
    });
    expect(consoleErrorSpy).not.toHaveBeenCalled();
  });

  it('falls back to the field defaults and logs when findGlobal rejects (unreachable DB / missing table)', async () => {
    mockFindGlobal.mockRejectedValue(new Error('connect ECONNREFUSED'));

    const hero = await getHeroContent();

    expect(hero).toEqual(heroFieldDefaults);
    expect(consoleErrorSpy).toHaveBeenCalled();
  });

  it('falls back to the field defaults and logs when getPayload itself rejects', async () => {
    mockGetPayload.mockRejectedValue(
      new Error('relation "hero" does not exist'),
    );

    const hero = await getHeroContent();

    expect(hero).toEqual(heroFieldDefaults);
    expect(consoleErrorSpy).toHaveBeenCalled();
  });
});
