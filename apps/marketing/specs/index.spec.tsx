import { render, screen } from '@testing-library/react';
import Page from '../src/app/(marketing)/page';

// jest.mock() factories are hoisted above module-scope const declarations,
// so this can't reference an outer `mockedHero` const without a
// ReferenceError (TDZ) — the literal is duplicated below instead.
const mockedHeadline = 'Test headline';

jest.mock('../src/lib/get-hero-content', () => ({
  getHeroContent: jest.fn().mockResolvedValue({
    headline: 'Test headline',
    subhead: 'Test subhead',
    ctaLabel: 'Test CTA',
    ctaHref: 'https://example.com',
  }),
}));

jest.mock('gsap', () => {
  const timeline = { from: jest.fn().mockReturnThis(), kill: jest.fn() };
  return {
    __esModule: true,
    default: {
      registerPlugin: jest.fn(),
      matchMedia: jest.fn(() => ({ add: jest.fn(), revert: jest.fn() })),
      timeline: jest.fn(() => timeline),
      quickTo: jest.fn(() => jest.fn()),
      to: jest.fn(() => ({
        kill: jest.fn(),
        scrollTrigger: { kill: jest.fn() },
      })),
      set: jest.fn(),
    },
  };
});

jest.mock('gsap/ScrollTrigger', () => ({ ScrollTrigger: {} }));

describe('Page', () => {
  // Page is an async Server Component (fetches hero content from Payload) —
  // resolve it ourselves before handing the element tree to RTL, since
  // ReactDOM's client renderer can't render an async component in place.
  it('should render successfully', async () => {
    const { baseElement } = render(await Page());
    expect(baseElement).toBeTruthy();
  });

  it('renders the mocked hero headline sourced from getHeroContent', async () => {
    render(await Page());

    expect(
      screen.getByRole('heading', { level: 1, name: mockedHeadline }),
    ).toBeTruthy();
  });
});
