#!/usr/bin/env bash
set -euo pipefail

# Scaffold a timestamped TypeORM migration at src/migrations/<ts>-<MigrationName>.ts
# Usage: scripts/new-migration.sh <MigrationName>

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "Usage: $0 <MigrationName>" >&2
  echo "  e.g. $0 CreateUsers" >&2
  exit 1
fi

migration_name="$1"

# Millisecond timestamp where supported, else fall back to seconds (portable).
timestamp="$(date +%s%3N 2>/dev/null || true)"
case "$timestamp" in
  *N|'') timestamp="$(date +%s)" ;;
esac

target_dir="src/migrations"
target_file="${target_dir}/${timestamp}-${migration_name}.ts"

if [ -e "$target_file" ]; then
  echo "Error: $target_file already exists; refusing to overwrite." >&2
  exit 1
fi

mkdir -p "$target_dir"

cat > "$target_file" <<EOF
import { MigrationInterface, QueryRunner } from 'typeorm';

export class ${migration_name}${timestamp} implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // TODO: implement forward migration
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // TODO: implement rollback
  }
}
EOF

echo "Created $target_file"
