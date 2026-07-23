import { render, screen } from '@testing-library/react';

import { RenderBlocks } from './render-blocks';

// Stub RichText so the test asserts wiring, not lexical internals.
jest.mock('@payloadcms/richtext-lexical/react', () => ({
  RichText: ({ data }: { data: unknown }) => (
    <div data-testid="richtext">{JSON.stringify(data)}</div>
  ),
}));

const lexical = {
  root: {
    type: 'root',
    children: [],
    direction: 'ltr',
    format: '',
    indent: 0,
    version: 1,
  },
};

describe('RenderBlocks', () => {
  it('renders a richText block via <RichText>', () => {
    render(
      <RenderBlocks
        blocks={[{ blockType: 'richText', richText: lexical } as never]}
      />,
    );
    expect(screen.getByTestId('richtext')).not.toBeNull();
  });

  it('renders a media block as a figure with img alt + caption', () => {
    render(
      <RenderBlocks
        blocks={[
          {
            blockType: 'media',
            media: { url: '/img.png', alt: 'Alt text' },
            caption: 'A caption',
          } as never,
        ]}
      />,
    );
    const img = screen.getByRole('img');
    expect(img.getAttribute('src')).toBe('/img.png');
    expect(img.getAttribute('alt')).toBe('Alt text');
    expect(screen.getByText('A caption')).not.toBeNull();
  });

  it('renders nothing (and warns) for an unknown blockType', () => {
    const warn = jest
      .spyOn(console, 'warn')
      .mockImplementation(() => undefined);
    const { container } = render(
      <RenderBlocks blocks={[{ blockType: 'cta' } as never]} />,
    );
    expect(container.innerHTML).toBe('');
    expect(warn).toHaveBeenCalled();
    warn.mockRestore();
  });

  it('renders nothing for an empty blocks array', () => {
    const { container } = render(<RenderBlocks blocks={[]} />);
    expect(container.innerHTML).toBe('');
  });
});
