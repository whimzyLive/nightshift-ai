import { render, screen, fireEvent } from '@testing-library/react';
import { InstallSnippet } from './InstallSnippet';

describe('InstallSnippet', () => {
  it('copies the command to the clipboard on click', async () => {
    const writeText = jest.fn().mockResolvedValue(undefined);
    Object.assign(navigator, { clipboard: { writeText } });
    render(<InstallSnippet command="/plugin install nightshift" />);
    fireEvent.click(screen.getByRole('button', { name: /copy/i }));
    expect(writeText).toHaveBeenCalledWith('/plugin install nightshift');
  });
});
