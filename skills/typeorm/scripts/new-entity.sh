#!/usr/bin/env bash
set -euo pipefail

# Scaffold a TypeORM entity at src/entities/<EntityName>.ts
# Usage: scripts/new-entity.sh <EntityName>

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "Usage: $0 <EntityName>" >&2
  echo "  e.g. $0 User" >&2
  exit 1
fi

entity_name="$1"
target_dir="src/entities"
target_file="${target_dir}/${entity_name}.ts"

if [ -e "$target_file" ]; then
  echo "Error: $target_file already exists; refusing to overwrite." >&2
  exit 1
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
  id: number;

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'boolean', default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
EOF

echo "Created $target_file"
