import { RichText } from '@payloadcms/richtext-lexical/react';

import type { Page } from '../../payload-types';

type PageBlock = Page['content'][number];

/**
 * Server-side block registry for the CMS `[slug]` page. Maps each entry of the
 * `content` blocks array to a component by `blockType`. An unknown blockType
 * renders nothing and is logged, so a newly-added-but-unrendered block can
 * never crash the page.
 */
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
      if (!media || typeof media !== 'object') return null;
      return (
        <figure key={index} className="my-8">
          <img src={media.url ?? ''} alt={media.alt ?? ''} className="w-full" />
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
