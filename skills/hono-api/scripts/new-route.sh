#!/usr/bin/env bash
set -euo pipefail

# new-route.sh <name>
# Scaffolds a feature route following the hono-api route + schema pattern:
#   src/routes/<name>/schema.ts  — Zod request/response schemas for this route
#   src/routes/<name>/route.ts   — createRoute() + OpenAPIHono().openapi(...)
# Never overwrites an existing file.

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "usage: new-route.sh <name>   (e.g. new-route.sh orders)" >&2
  exit 1
fi

name="$1"
dir="src/routes/${name}"

# PascalCase the name for schema/type identifiers (orders -> Orders, user-profile -> UserProfile).
pascal="$(printf '%s' "$name" | awk -F'[-_ ]' '{ out=""; for (i=1; i<=NF; i++) out = out toupper(substr($i,1,1)) substr($i,2); print out }')"

case "$pascal" in
  [A-Za-z]*) : ;;
  *)
    echo "error: <name> must start with a letter (got '$name')" >&2
    exit 1
    ;;
esac

# camelCase identifier for JS variable names (user-profile -> userProfile); the path keeps the raw name.
camel="$(printf '%s' "$pascal" | awk '{ print tolower(substr($0,1,1)) substr($0,2) }')"

mkdir -p "$dir"

schema_file="${dir}/schema.ts"
route_file="${dir}/route.ts"

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

export const ${pascal}ResponseSchema = z.object({
  id: z.string(),
});

export type ${pascal}Response = z.infer<typeof ${pascal}ResponseSchema>;
EOF

write_file "$route_file" <<EOF
import { OpenAPIHono, createRoute } from '@hono/zod-openapi';
import { ${pascal}ResponseSchema } from './schema';

const ${camel}Route = createRoute({
  method: 'get',
  path: '/${name}',
  responses: {
    200: {
      content: { 'application/json': { schema: ${pascal}ResponseSchema } },
      description: '${pascal} resource',
    },
  },
});

export const ${camel}Router = new OpenAPIHono();

${camel}Router.openapi(${camel}Route, (c) => {
  return c.json({ id: '' });
});
EOF

echo "done. mount in app.ts:  app.route('/', ${camel}Router);"
