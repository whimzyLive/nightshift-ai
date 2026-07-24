import { fireEvent, render, screen, waitFor } from '@testing-library/react';

import { FinalCta } from './final-cta';

describe('FinalCta', () => {
  it('renders the header and body copy', () => {
    render(<FinalCta />);
    expect(
      screen.getByRole('heading', {
        name: 'Put a ticket in tonight. Read a reviewed PR in the morning.',
      }),
    ).toBeTruthy();
    expect(screen.getByText(/install takes about a minute/i)).toBeTruthy();
  });

  it('renders both install snippets with their exact commands', () => {
    render(<FinalCta />);
    expect(
      screen.getByText('/plugin marketplace add whimzyLive/nightshift-ai'),
    ).toBeTruthy();
    expect(screen.getByText('/plugin install sdlc@nightshift')).toBeTruthy();
  });

  it('copies each snippet command to the clipboard on its own copy click', async () => {
    const writeText = jest.fn().mockResolvedValue(undefined);
    Object.assign(navigator, { clipboard: { writeText } });

    render(<FinalCta />);
    const copyButtons = screen.getAllByRole('button', { name: /^copy:/i });
    expect(copyButtons).toHaveLength(2);

    copyButtons[0].click();
    expect(writeText).toHaveBeenCalledWith(
      '/plugin marketplace add whimzyLive/nightshift-ai',
    );

    copyButtons[1].click();
    expect(writeText).toHaveBeenCalledWith('/plugin install sdlc@nightshift');
  });

  it('renders the star button linking to the GitHub repo, opening in a new tab', () => {
    render(<FinalCta />);
    const link = screen.getByRole('link', {
      name: /star nightshift on github/i,
    });
    expect(link.getAttribute('href')).toBe(
      'https://github.com/whimzyLive/nightshift-ai',
    );
    expect(link.getAttribute('target')).toBe('_blank');
    expect(link.getAttribute('rel')).toBe('noopener');
  });

  it('pulls the star button toward the pointer on hover (B1 MagneticCta)', async () => {
    render(<FinalCta />);
    const link = screen.getByRole('link', {
      name: /star nightshift on github/i,
    });
    const wrapper = link.parentElement as HTMLElement;
    jest.spyOn(wrapper, 'getBoundingClientRect').mockReturnValue({
      width: 100,
      height: 40,
      top: 0,
      left: 0,
      right: 100,
      bottom: 40,
      x: 0,
      y: 0,
      toJSON: () => ({}),
    } as DOMRect);

    fireEvent.mouseMove(wrapper, { clientX: 90, clientY: 36 });
    await waitFor(() => {
      expect(wrapper.style.transform).not.toBe('');
      expect(wrapper.style.transform).not.toContain('NaN');
      expect(wrapper.style.transform).not.toContain('translateX(0px)');
    });
  });
});
