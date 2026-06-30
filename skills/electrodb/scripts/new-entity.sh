#!/usr/bin/env bash
set -euo pipefail

# new-entity.sh — scaffold an ElectroDB entity file.
#
# Usage: scripts/new-entity.sh <EntityName>
#   <EntityName>  PascalCase or any-case entity name, e.g. "OrderItem".
#                 A kebab-case filename is derived: src/entities/order-item.entity.ts
#
# Never overwrites an existing file. Uses coreutils only.

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "Usage: $0 <EntityName>" >&2
  echo "Example: $0 OrderItem  ->  src/entities/order-item.entity.ts" >&2
  exit 1
fi

raw_name="$1"

# Strip a trailing PascalCase "Entity" suffix if the caller included it (e.g.
# "OrderItemEntity" -> "OrderItem"), then normalise. Capital-E only, so names that
# merely end in the letters "entity" (e.g. "Identity") are left intact.
base="$(printf '%s' "$raw_name" | sed -E 's/Entity$//')"
if [ -z "$base" ]; then
  base="$raw_name"
fi

# Kebab-case: split camelCase/PascalCase boundaries, swap separators, lowercase.
kebab="$(printf '%s' "$base" \
  | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g; s/([A-Z]+)([A-Z][a-z])/\1-\2/g' \
  | tr '[:upper:]' '[:lower:]' \
  | tr ' _' '--' \
  | sed -E 's/-+/-/g; s/^-//; s/-$//')"

if [ -z "$kebab" ]; then
  echo "Error: could not derive a filename from '$raw_name'." >&2
  exit 1
fi

# PascalCase variable name for the exported const (e.g. order-item -> OrderItem).
var_name="$(printf '%s' "$kebab" | awk -F'-' '{
  out = ""
  for (i = 1; i <= NF; i++) out = out toupper(substr($i, 1, 1)) substr($i, 2)
  print out
}')"

# camelCase id attribute base (e.g. order-item -> orderItem).
camel="$(printf '%s' "$var_name" | awk '{ print tolower(substr($0, 1, 1)) substr($0, 2) }')"

# entity namespace value (lowercase, no separators).
entity_value="$(printf '%s' "$kebab" | tr -d '-')"

out_dir="src/entities"
out_file="${out_dir}/${kebab}.entity.ts"

if [ -e "$out_file" ]; then
  echo "Skipping: $out_file already exists (not overwriting)." >&2
  exit 0
fi

mkdir -p "$out_dir"

cat > "$out_file" <<EOF
import { randomUUID } from "node:crypto";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";
import { Entity } from "electrodb";

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));

export const ${var_name} = new Entity(
  {
    model: {
      entity: "${entity_value}",
      service: "app",
      version: "1",
    },
    attributes: {
      ${camel}Id: {
        type: "string",
        required: true,
        default: () => randomUUID(),
      },
      ownerId: { type: "string", required: true },
      status: {
        type: ["active", "archived"] as const,
        required: true,
        default: "active",
      },
      ttl: { type: "number" }, // epoch seconds for DynamoDB TTL
      createdAt: {
        type: "string",
        readOnly: true,
        default: () => new Date().toISOString(),
      },
      updatedAt: {
        type: "string",
        watch: "*",
        set: () => new Date().toISOString(),
      },
    },
    indexes: {
      // Primary table index (no \`index\` property).
      primary: {
        pk: { field: "pk", composite: ["${camel}Id"] },
        sk: { field: "sk", composite: ["ownerId"] },
      },
      // GSI — query by owner, sorted by creation time.
      byOwner: {
        index: "gsi1pk-gsi1sk-index",
        pk: { field: "gsi1pk", composite: ["ownerId"] },
        sk: { field: "gsi1sk", composite: ["createdAt", "${camel}Id"] },
      },
    },
  },
  { table: process.env.TABLE_NAME!, client },
);
EOF

echo "Created $out_file"
