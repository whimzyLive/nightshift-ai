import { render, screen } from '@testing-library/react';

import { PageCta } from './page-cta';
import { useScrollProgress } from './scroll-progress';

jest.mock('./scroll-progress', () => ({ useScrollProgress: jest.fn() }));

const mockUseScrollProgress = useScrollProgress as jest.Mock;

describe('PageCta', () => {
  beforeEach(() => {
    mockUseScrollProgress
      .mockReset()
      .mockReturnValue({ reached: 0, active: 0 });
  });

  it('renders the CtaKicker copy', () => {
    render(<PageCta />);
    expect(
      screen.getByText('⊘ 1 of 5 gates ahead — the rail lights as you read'),
    ).toBeTruthy();
  });

  it('renders the heading', () => {
    render(<PageCta />);
    expect(
      screen.getByRole('heading', {
        name: 'Put the lifecycle back in your hands',
      }),
    ).toBeTruthy();
  });

  it('renders both install snippets', () => {
    render(<PageCta />);
    expect(
      screen.getByText('/plugin marketplace add whimzyLive/nightshift-ai'),
    ).toBeTruthy();
    expect(screen.getByText('/plugin install sdlc@nightshift')).toBeTruthy();
  });

  it('renders the GitHub star button linking the repo', () => {
    render(<PageCta />);
    const link = screen.getByRole('link', {
      name: '★ Star nightshift on GitHub',
    });
    expect(link.getAttribute('href')).toBe(
      'https://github.com/whimzyLive/nightshift-ai',
    );
    expect(link.getAttribute('rel')).toBe('noopener');
  });

  it('renders the back-to-overview link to /', () => {
    render(<PageCta />);
    const link = screen.getByRole('link', { name: '← Back to overview' });
    expect(link.getAttribute('href')).toBe('/');
  });
});
