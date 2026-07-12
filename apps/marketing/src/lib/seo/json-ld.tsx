import type { JsonLdGraph } from './jsonld';

/**
 * Renders one `<script type="application/ld+json">` with the serialized
 * graph. Plain server component, no client JS — the graph is fully resolved
 * by the caller before this renders.
 */
export function JsonLd({ graph }: { graph: JsonLdGraph }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(graph) }}
    />
  );
}
