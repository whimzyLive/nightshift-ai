import React from 'react';
import { render, screen } from '@testing-library/react';
import { HeroClient } from '../src/components/hero/hero-client';

let capturedMatchMediaHandler:
  | ((context: { conditions: Record<string, boolean> }) => void)
  | undefined;

jest.mock('gsap', () => {
  const timeline = { from: jest.fn().mockReturnThis(), kill: jest.fn() };
  return {
    __esModule: true,
    default: {
      registerPlugin: jest.fn(),
      matchMedia: jest.fn(() => ({
        add: jest.fn((_query, handler) => {
          capturedMatchMediaHandler = handler;
        }),
        revert: jest.fn(),
      })),
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

const props = {
  headline: 'Your AI software team that ships while you sleep',
  subhead: 'A test subhead sourced from Payload.',
  ctaLabel: 'Install the plugin',
  ctaHref: 'https://github.com/whimzyLive/nightshift-ai',
};

describe('HeroClient', () => {
  beforeEach(() => {
    capturedMatchMediaHandler = undefined;
    jest.clearAllMocks();
  });

  it('renders the CMS-sourced headline, subhead, and CTA', () => {
    render(<HeroClient {...props} />);

    expect(
      screen.getByRole('heading', { level: 1, name: props.headline }),
    ).toBeTruthy();
    expect(screen.getByText(props.subhead)).toBeTruthy();

    const cta = screen.getByRole('link', { name: props.ctaLabel });
    expect(cta.getAttribute('href')).toBe(props.ctaHref);
  });

  it('hides the decorative sky backdrop from assistive tech', () => {
    const { container } = render(<HeroClient {...props} />);
    const stage = container.querySelector('[aria-hidden="true"]');

    expect(stage).not.toBeNull();
  });

  it('registers a prefers-reduced-motion matchMedia query on mount', () => {
    const gsap = jest.requireMock('gsap').default;

    render(<HeroClient {...props} />);

    expect(gsap.matchMedia).toHaveBeenCalled();
  });

  it('skips the entrance timeline and jumps to the final state when reduced motion is preferred', () => {
    const gsap = jest.requireMock('gsap').default;

    render(<HeroClient {...props} />);
    capturedMatchMediaHandler?.({ conditions: { reduceMotion: true } });

    expect(gsap.set).toHaveBeenCalled();
    expect(gsap.timeline).not.toHaveBeenCalled();
  });

  it('runs the entrance timeline and mouse-parallax setup when motion is allowed', () => {
    const gsap = jest.requireMock('gsap').default;

    render(<HeroClient {...props} />);
    capturedMatchMediaHandler?.({ conditions: { reduceMotion: false } });

    expect(gsap.timeline).toHaveBeenCalled();
    expect(gsap.quickTo).toHaveBeenCalledWith(
      expect.anything(),
      'rotationX',
      expect.any(Object),
    );
    expect(gsap.quickTo).toHaveBeenCalledWith(
      expect.anything(),
      'rotationY',
      expect.any(Object),
    );
  });
});
