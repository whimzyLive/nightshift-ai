import { convertLexicalToPlaintext } from '@payloadcms/richtext-lexical/plaintext';

import type { SerializedEditorState } from '@payloadcms/richtext-lexical/lexical';

/**
 * Converts one FAQ answer's Lexical value to plaintext for JSON-LD's
 * `acceptedAnswer.text`. Never throws (Error Handling: a converter failure
 * must not break the page) — falls back to an empty string.
 */
export function faqAnswerToPlaintext(answer: SerializedEditorState): string {
  try {
    return convertLexicalToPlaintext({ data: answer });
  } catch (error) {
    console.error('[seo]', error);
    return '';
  }
}
