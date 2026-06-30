#!/usr/bin/env bash
set -euo pipefail

# Scaffold a TypeORM entity at src/entities/<EntityName>.ts
# Usage: scripts/new-entity.sh <EntityName>

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "Usage: $0 <EntityName>" >&2
  echo "  e.g. $0 User" >&2
  exit 1
fi

# Normalize the argument to a valid PascalCase class identifier (order-item / user_profile
# / "User Profile" -> OrderItem / UserProfile), so the generated TypeScript always compiles.
entity_name="$(printf '%s' "$1" \
  | sed -E 's/([a-z0-9])([A-Z])/\1 \2/g' \
  | tr '_-' '  ' \
  | awk '{ out=""; for (i=1; i<=NF; i++) out = out toupper(substr($i,1,1)) substr($i,2); print out }')"

case "$entity_name" in
  [A-Za-z]*) : ;;
  *)
    echo "Error: <EntityName> must start with a letter (got '$1')." >&2
    exit 1
    ;;
esac

target_dir="src/entities"
target_file="${target_dir}/${entity_name}.ts"

if [ -e "$target_file" ]; then
  echo "Skipping: $target_file already exists (not overwriting)." >&2
  exit 0
fi

mkdir -p "$target_dir"

cat > "$target_file" <<EOF
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity()
export class ${entity_name} {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: 'varchar', length: 255 })
  name!: string;

  @Column({ type: 'boolean', default: true })
  isActive!: boolean;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
EOF

echo "Created $target_file"
