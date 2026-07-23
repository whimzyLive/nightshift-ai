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

  it('renders a media block as a figure with img alt + caption + dimensions', () => {
    render(
      <RenderBlocks
        blocks={[
          { blockType: 'richText', richText: lexical } as never,
          {
            blockType: 'media',
            media: {
              url: '/img.png',
              alt: 'Alt text',
              width: 800,
              height: 600,
            },
            caption: 'A caption',
          } as never,
        ]}
      />,
    );
    const img = screen.getByRole('img');
    expect(img.getAttribute('src')).toBe('/img.png');
    expect(img.getAttribute('alt')).toBe('Alt text');
    expect(img.getAttribute('width')).toBe('800');
    expect(img.getAttribute('height')).toBe('600');
    expect(img.getAttribute('loading')).toBe('lazy');
    expect(screen.getByText('A caption')).not.toBeNull();
  });

  it('loads the first block eagerly (LCP) and later blocks lazily', () => {
    render(
      <RenderBlocks
        blocks={[
          {
            blockType: 'media',
            media: { url: '/hero.png', alt: 'Hero', width: 800, height: 600 },
          } as never,
          {
            blockType: 'media',
            media: {
              url: '/second.png',
              alt: 'Second',
              width: 400,
              height: 300,
            },
          } as never,
        ]}
      />,
    );
    const images = screen.getAllByRole('img');
    expect(images[0].getAttribute('loading')).not.toBe('lazy');
    expect(images[0].getAttribute('fetchpriority')).toBe('high');
    expect(images[1].getAttribute('loading')).toBe('lazy');
  });

  it('renders only a figcaption when media has a caption but no usable url', () => {
    const { container } = render(
      <RenderBlocks
        blocks={[
          {
            blockType: 'media',
            media: { alt: 'Alt text' },
            caption: 'A caption',
          } as never,
        ]}
      />,
    );
    expect(container.querySelector('img')).toBeNull();
    expect(screen.getByText('A caption')).not.toBeNull();
  });

  it('renders nothing when media has neither a usable url nor a caption', () => {
    const { container } = render(
      <RenderBlocks
        blocks={[{ blockType: 'media', media: { alt: 'Alt text' } } as never]}
      />,
    );
    expect(container.innerHTML).toBe('');
  });

  it('omits width/height entirely when the media doc has only one dimension', () => {
    render(
      <RenderBlocks
        blocks={[
          {
            blockType: 'media',
            media: { url: '/img.png', alt: 'Alt text', width: 800 },
          } as never,
        ]}
      />,
    );
    const img = screen.getByRole('img');
    expect(img.getAttribute('width')).toBeNull();
    expect(img.getAttribute('height')).toBeNull();
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
