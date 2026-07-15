import { fireEvent, render, screen, waitFor } from '@testing-library/react';

import { InstallSnippet } from './install-snippet';

const COMMAND = '/plugin marketplace add whimzyLive/nightshift-ai';

describe('InstallSnippet', () => {
  it('renders the prompt and the exact command text', () => {
    render(<InstallSnippet command={COMMAND} />);
    expect(screen.getByText(COMMAND)).toBeTruthy();
    expect(screen.getByText('$')).toBeTruthy();
  });

  it('copies the exact command via navigator.clipboard.writeText and shows a confirmation', async () => {
    const writeText = jest.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', {
      value: { writeText },
      configurable: true,
    });

    render(<InstallSnippet command={COMMAND} />);
    const button = screen.getByRole('button', { name: `Copy: ${COMMAND}` });
    fireEvent.click(button);

    expect(writeText).toHaveBeenCalledWith(COMMAND);
    await waitFor(() => expect(button.textContent).toBe('copied'));
  });

  it('does not throw and keeps the command visible when navigator.clipboard is unavailable', () => {
    Object.defineProperty(navigator, 'clipboard', {
      value: undefined,
      configurable: true,
    });

    render(<InstallSnippet command={COMMAND} />);
    const button = screen.getByRole('button', { name: `Copy: ${COMMAND}` });

    expect(() => fireEvent.click(button)).not.toThrow();
    expect(screen.getByText(COMMAND)).toBeTruthy();
  });
});
