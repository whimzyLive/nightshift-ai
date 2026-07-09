import { fireEvent, render, screen, waitFor } from '@testing-library/react';

import { InstallSnippet } from './install-snippet';

describe('InstallSnippet', () => {
  const writeText = jest.fn().mockResolvedValue(undefined);

  beforeEach(() => {
    writeText.mockClear();
    Object.assign(navigator, { clipboard: { writeText } });
  });

  it('renders the default install command with a $ prompt', () => {
    render(<InstallSnippet />);

    expect(screen.getByText('/plugin install sdlc@nightshift')).toBeTruthy();
    expect(screen.getByText('$')).toBeTruthy();
  });

  it('renders a custom command and prompt', () => {
    render(
      <InstallSnippet
        command="/plugin marketplace add whimzyLive/nightshift-ai"
        prompt="$"
      />
    );

    expect(
      screen.getByText('/plugin marketplace add whimzyLive/nightshift-ai')
    ).toBeTruthy();
  });

  it('copies the command to the clipboard and confirms with "copied ✓"', async () => {
    render(<InstallSnippet command="/plugin install sdlc@nightshift" />);

    fireEvent.click(screen.getByRole('button', { name: /copy command/i }));

    expect(writeText).toHaveBeenCalledWith('/plugin install sdlc@nightshift');
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /copied/i })).toBeTruthy();
    });
  });
});
