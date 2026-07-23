import { RichText } from '@payloadcms/richtext-lexical/react';

import type { Page } from '../../payload-types';

type PageBlock = Page['content'][number];

export function RenderBlocks({ blocks }: { blocks: Page['content'] }) {
  if (!blocks?.length) return null;
  return <>{blocks.map((block, index) => renderBlock(block, index))}</>;
}

function renderBlock(block: PageBlock, index: number) {
  switch (block.blockType) {
    case 'richText':
      return <RichText key={index} data={block.richText} disableContainer />;
    case 'media': {
      const media = block.media;
      if (!media || typeof media !== 'object' || !media.url) return null;
      return (
        <figure key={index} className="my-8">
          <img
            src={media.url}
            alt={media.alt ?? ''}
            width={media.width ?? undefined}
            height={media.height ?? undefined}
            loading="lazy"
            className="w-full"
          />
          {block.caption ? (
            <figcaption
              className="mt-2 text-sm"
              style={{ color: 'var(--text-muted)' }}
            >
              {block.caption}
            </figcaption>
          ) : null}
        </figure>
      );
    }
    default:
      console.warn(
        '[render-blocks] unknown blockType',
        (block as { blockType?: string }).blockType,
      );
      return null;
  }
}
