import type { JsonLdGraph } from './jsonld';

/**
 * Renders one `<script type="application/ld+json">` with the serialized
 * graph. Plain server component, no client JS — the graph is fully resolved
 * by the caller before this renders.
 */
export function JsonLd({ graph }: { graph: JsonLdGraph }) {
  // Escape `<` (and by extension `</script>` / `<!--`) so CMS-sourced strings
  // in the graph can never break out of the <script> element. `<` keeps
  // the payload valid JSON that application/ld+json still parses.
  const html = JSON.stringify(graph).replace(/</g, '\\u003c');
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: html }}
    />
  );
}
