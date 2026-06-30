#!/usr/bin/env bash
set -euo pipefail

# new-service.sh <noun>
# Scaffolds a class-based service following the hono-api service-layer pattern:
#   src/services/<noun>/schema.ts            — Zod schemas + inferred types for this service
#   src/services/<noun>/service.interface.ts — the I<Noun>Service contract
#   src/services/<noun>/service.ts           — class <Noun>Service implements I<Noun>Service (+ singleton)
# Never overwrites an existing file.

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "usage: new-service.sh <noun>   (e.g. new-service.sh order)" >&2
  exit 1
fi

noun="$1"
dir="src/services/${noun}"

# PascalCase the noun for type/class identifiers (order -> Order, payment-intent -> PaymentIntent).
pascal="$(printf '%s' "$noun" | awk -F'[-_ ]' '{ out=""; for (i=1; i<=NF; i++) out = out toupper(substr($i,1,1)) substr($i,2); print out }')"

if [ -z "$pascal" ]; then
  echo "error: <noun> must contain at least one alphanumeric character" >&2
  exit 1
fi

# camelCase singleton name (first char of PascalCase lowercased).
camel="$(printf '%s' "$pascal" | awk '{ print tolower(substr($0,1,1)) substr($0,2) }')"

mkdir -p "$dir"

schema_file="${dir}/schema.ts"
interface_file="${dir}/service.interface.ts"
service_file="${dir}/service.ts"

write_file() {
  # write_file <path> <heredoc-content-on-stdin>
  local path="$1"
  if [ -e "$path" ]; then
    echo "skip: ${path} already exists" >&2
    return 0
  fi
  cat > "$path"
  echo "created: ${path}"
}

write_file "$schema_file" <<EOF
import { z } from 'zod';

export const ${pascal}Schema = z.object({
  id: z.string(),
});

export const Create${pascal}Schema = ${pascal}Schema.omit({ id: true });

export type ${pascal} = z.infer<typeof ${pascal}Schema>;
export type Create${pascal} = z.infer<typeof Create${pascal}Schema>;
EOF

write_file "$interface_file" <<EOF
import type { ${pascal}, Create${pascal} } from './schema';

export interface I${pascal}Service {
  get(id: string): Promise<${pascal} | null>;
  create(input: Create${pascal}): Promise<${pascal}>;
}
EOF

write_file "$service_file" <<EOF
import type { ${pascal}, Create${pascal} } from './schema';
import type { I${pascal}Service } from './service.interface';

export class ${pascal}Service implements I${pascal}Service {
  async get(_id: string): Promise<${pascal} | null> {
    return null;
  }

  async create(_input: Create${pascal}): Promise<${pascal}> {
    throw new Error('not implemented');
  }
}

// Import this singleton (typed as the interface), not the class.
export const ${camel}Service: I${pascal}Service = new ${pascal}Service();
EOF

echo "done."
