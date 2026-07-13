import {
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from '@testing-library/react';

import { isActiveLink, NavBar } from './nav-bar';

const mockUsePathname = jest.fn();

jest.mock('next/navigation', () => ({
  usePathname: () => mockUsePathname(),
}));

describe('isActiveLink', () => {
  it('treats an in-page anchor link as active only on the home route', () => {
    expect(isActiveLink('/', '/#how-it-works')).toBe(true);
    expect(isActiveLink('/faq', '/#how-it-works')).toBe(false);
  });

  it('matches a plain route link by exact pathname', () => {
    expect(isActiveLink('/why-sdlc', '/why-sdlc')).toBe(true);
    expect(isActiveLink('/team', '/why-sdlc')).toBe(false);
  });
});

describe('NavBar', () => {
  beforeEach(() => {
    mockUsePathname.mockReturnValue('/why-sdlc');
  });

  it('renders the 4 nav links, the GitHub icon link, and the primary CTA', () => {
    render(<NavBar />);
    const labels = screen.getAllByRole('link').map((l) => l.textContent);
    // 4 nav links + logo + GitHub icon (count "4") + CTA
    expect(labels).toEqual(
      expect.arrayContaining([
        'How it works',
        'Why SDLC',
        'The team',
        'FAQ',
        'Install the plugin',
      ]),
    );
    // GitHub moved out of the nav to an icon link — accessible name via aria-label.
    expect(screen.getByRole('link', { name: 'GitHub' })).toBeTruthy();
  });

  it('marks the current route link active and others not', () => {
    render(<NavBar />);
    const activeLink = screen.getByRole('link', { name: 'Why SDLC' });
    const inactiveLink = screen.getByRole('link', { name: 'FAQ' });
    expect(activeLink.getAttribute('aria-current')).toBe('page');
    expect(inactiveLink.getAttribute('aria-current')).toBeNull();
  });

  it('opens the GitHub link in a new tab safely', () => {
    render(<NavBar />);
    const githubLink = screen.getByRole('link', { name: 'GitHub' });
    expect(githubLink.getAttribute('href')).toBe(
      'https://github.com/whimzyLive/nightshift-ai',
    );
    expect(githubLink.getAttribute('target')).toBe('_blank');
    expect(githubLink.getAttribute('rel')).toBe('noopener noreferrer');
  });
});

describe('NavBar floating detach', () => {
  const setViewport = (width: number, scrollY: number) => {
    (window as { innerWidth: number }).innerWidth = width;
    Object.defineProperty(window, 'scrollY', {
      value: scrollY,
      configurable: true,
    });
  };

  beforeEach(() => {
    mockUsePathname.mockReturnValue('/');
  });

  it('detaches into the floating pill past the threshold at lg and up', () => {
    setViewport(1280, 500);
    const { container } = render(<NavBar />);
    fireEvent.scroll(window);
    expect(container.querySelector('header')?.style.transform).toBe(
      'translateX(-50%)',
    );
  });

  it('never floats below the lg breakpoint, even scrolled past the threshold', () => {
    setViewport(500, 500);
    const { container } = render(<NavBar />);
    fireEvent.scroll(window);
    expect(container.querySelector('header')?.style.transform).toBe('');
  });
});

describe('NavBar mobile overlay', () => {
  beforeEach(() => {
    mockUsePathname.mockReturnValue('/why-sdlc');
  });

  it('renders a closed hamburger toggle', () => {
    render(<NavBar />);
    const toggle = screen.getByRole('button', { name: 'Open menu' });
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('opens a dialog overlay exposing the links and both CTAs', () => {
    render(<NavBar />);
    fireEvent.click(screen.getByRole('button', { name: 'Open menu' }));

    const dialog = screen.getByRole('dialog');
    const menu = within(dialog);
    expect(
      screen
        .getByRole('button', { name: 'Open menu' })
        .getAttribute('aria-expanded'),
    ).toBe('true');
    [
      'How it works',
      'Why SDLC',
      'The team',
      'FAQ',
      'Install the plugin',
    ].forEach((label) =>
      expect(menu.getByRole('link', { name: label })).toBeTruthy(),
    );
    expect(menu.getByRole('link', { name: 'GitHub' })).toBeTruthy();
  });

  it('marks the active route in the overlay list', () => {
    render(<NavBar />);
    fireEvent.click(screen.getByRole('button', { name: 'Open menu' }));
    const menu = within(screen.getByRole('dialog'));
    expect(
      menu.getByRole('link', { name: 'Why SDLC' }).getAttribute('aria-current'),
    ).toBe('page');
  });

  it('closes on the Close button', async () => {
    render(<NavBar />);
    fireEvent.click(screen.getByRole('button', { name: 'Open menu' }));
    fireEvent.click(screen.getByRole('button', { name: 'Close menu' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  });

  it('closes on Escape', async () => {
    render(<NavBar />);
    fireEvent.click(screen.getByRole('button', { name: 'Open menu' }));
    fireEvent.keyDown(window, { key: 'Escape' });
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  });

  it('closes when an overlay link is clicked', async () => {
    render(<NavBar />);
    fireEvent.click(screen.getByRole('button', { name: 'Open menu' }));
    const menu = within(screen.getByRole('dialog'));
    fireEvent.click(menu.getByRole('link', { name: 'FAQ' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  });

  it('locks body scroll while open and restores it on close', async () => {
    render(<NavBar />);
    fireEvent.click(screen.getByRole('button', { name: 'Open menu' }));
    expect(document.body.style.overflow).toBe('hidden');
    fireEvent.click(screen.getByRole('button', { name: 'Close menu' }));
    await waitFor(() => expect(document.body.style.overflow).toBe(''));
  });
});
