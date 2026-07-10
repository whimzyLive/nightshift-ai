import { render, screen, fireEvent, act } from '@testing-library/react';
import { InstallSnippet } from './InstallSnippet';

describe('InstallSnippet', () => {
  it('copies the command to the clipboard on click', async () => {
    const writeText = jest.fn().mockResolvedValue(undefined);
    Object.assign(navigator, { clipboard: { writeText } });
    render(<InstallSnippet command="/plugin install nightshift" />);
    fireEvent.click(screen.getByRole('button', { name: /copy/i }));
    expect(writeText).toHaveBeenCalledWith('/plugin install nightshift');
  });

  it('renders an optional caption label above the command line', () => {
    render(
      <InstallSnippet
        command="/plugin install nightshift"
        label="Install in 60 seconds"
      />,
    );
    expect(screen.getByText('Install in 60 seconds')).toBeTruthy();
  });

  it('renders no label element when label is omitted', () => {
    render(<InstallSnippet command="/plugin install nightshift" />);
    expect(screen.queryByText(/install/i, { selector: 'span' })).toBeNull();
  });

  it('updates the aria-label to reflect the copied state', async () => {
    const writeText = jest.fn().mockResolvedValue(undefined);
    Object.assign(navigator, { clipboard: { writeText } });
    render(<InstallSnippet command="/plugin install nightshift" />);
    const button = screen.getByRole('button', { name: 'Copy install command' });
    await act(async () => {
      fireEvent.click(button);
    });
    expect(button.getAttribute('aria-label')).toBe('Copied install command');
  });

  it('does not throw and shows a non-crashing failed state when the Clipboard API is unavailable', async () => {
    Object.assign(navigator, { clipboard: undefined });
    render(<InstallSnippet command="/plugin install nightshift" />);
    const button = screen.getByRole('button', { name: 'Copy install command' });
    await act(async () => {
      fireEvent.click(button);
    });
    expect(button.getAttribute('aria-label')).toBe(
      'Failed to copy install command',
    );
    expect(button.textContent).toBe('Failed');
  });

  it('does not throw and shows a non-crashing failed state when writeText rejects', async () => {
    const writeText = jest.fn().mockRejectedValue(new Error('denied'));
    Object.assign(navigator, { clipboard: { writeText } });
    render(<InstallSnippet command="/plugin install nightshift" />);
    const button = screen.getByRole('button', { name: 'Copy install command' });
    await act(async () => {
      fireEvent.click(button);
    });
    expect(button.getAttribute('aria-label')).toBe(
      'Failed to copy install command',
    );
  });
});
