import { RichText as LexicalRichText } from '@payloadcms/richtext-lexical/react';
import type { SerializedEditorState } from '@payloadcms/richtext-lexical/lexical';

export function RichText({ data }: { data?: SerializedEditorState | null }) {
  if (!data?.root?.children?.length) return null;
  // `space-y-*` puts vertical rhythm between whatever block-level elements
  // the lexical→React converter renders (paragraphs today, headings/lists
  // if the editor config ever grows) without needing a typography plugin.
  return (
    <div className="space-y-4 leading-relaxed">
      <LexicalRichText data={data} />
    </div>
  );
}
