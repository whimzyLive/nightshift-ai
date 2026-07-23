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
      const hasUrl = media && typeof media === 'object' && media.url;
      if (!hasUrl && !block.caption) return null;
      const dimensions =
        media &&
        typeof media === 'object' &&
        media.width != null &&
        media.height != null
          ? { width: media.width, height: media.height }
          : {};
      const isFirst = index === 0;
      return (
        <figure key={index} className="my-8">
          {hasUrl && media && typeof media === 'object' ? (
            <img
              src={media.url ?? undefined}
              alt={media.alt ?? ''}
              {...dimensions}
              loading={isFirst ? 'eager' : 'lazy'}
              fetchPriority={isFirst ? 'high' : undefined}
              className="w-full"
            />
          ) : null}
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
